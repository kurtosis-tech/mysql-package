MYSQL_IMAGE = "mysql:8.0.32"
ROOT_DEFAULT_PASSWORD = "root"
MYSQL_DEFAULT_PORT = 3036

def create_database(plan, database_name, database_user, database_password, seed_script_artifact = None):
    files = {}
    # Given that scripts on /docker-entrypoint-initdb.d/ are executed sorted by filename
    if seed_script_artifact != None:
        files["/docker-entrypoint-initdb.d"] = seed_script_artifact
    service_name = "mysql-{}".format(database_name)
    mysql_service = plan.add_service(
        name = service_name,
        config = ServiceConfig(
            image = MYSQL_IMAGE,
            ports = {
                "db": PortSpec(
                    number = MYSQL_DEFAULT_PORT,
                    transport_protocol = "TCP",
                    application_protocol = "http",
                ),
            },
            files = files,
            env_vars = {
                "MYSQL_ROOT_PASSWORD": ROOT_DEFAULT_PASSWORD,
                "MYSQL_DATABASE": database_name,
                "MYSQL_USER": database_user,
                "MYSQL_PASSWORD":  database_password,
            },
            # Conditions that, when satisifed, confirm that a service is ready to receive connections and traffic after its been started (defined later)
            ready_conditions = ReadyCondition,
        )
    )
    # Define the readiness conditions 
    ready_conditions = ReadyCondition(
        recipe = ExecRecipe(
            command = ["mysql", "-u", database_user, "-p{}".format(database_password), database_name]
            ),
        field = "code",
        assertion = "==",
        target_value = 0,
        timeout = "30s",
    )

    # test a generic query works
    test_query = "show tables"
    plan.wait(
        service_name = service_name,
        recipe = ExecRecipe(command = ["sh", "-c", "mysql -u {} -p{} -e '{}' {}".format(database_user, database_password, test_query, database_name)]),
        field = "code",
        assertion = "==",
        target_value = 0,
        timeout = "30s",
    )


    return struct(
        service=mysql_service,
        name=database_name,
        user=database_user,
        password=database_password,
    )


def run_sql(plan, database, sql_query):
    exec_result = plan.exec(
        service_name = database.service.name,
        recipe = ExecRecipe(command = ["sh", "-c", "mysql -u {} -p{} -e '{}' {}".format(database.user, database.password, sql_query, database.name)]),
    )
    return exec_result["output"]
