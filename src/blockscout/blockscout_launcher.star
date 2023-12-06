shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

SERVICE_NAME = "blockscout"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 4000

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_blockscout(
    plan,
    el_client_contexts,
):
    # https://github.com/kurtosis-tech/postgres-package/blob/main/main.star
    postgres_output = postgres.run(plan, service_name="{}-postgres".format(SERVICE_NAME), database="blockscout")

    el_client_context = el_client_contexts[0]
    el_client_rpc_url = "http://{}:{}/".format(el_client_context.ip_addr, el_client_context.rpc_port_num)    
    config = get_config(postgres_output, el_client_rpc_url)

    plan.add_service(SERVICE_NAME, config)


def get_config(postgres_output, el_client_rpc_url):
    IMAGE_NAME = "blockscout/blockscout:5.3.2"
    
    # BUG: broken because url is missing port
    # database_url = postgres_output.url

    database_url = "{protocol}://{user}:{password}@{hostname}:{port}/{database}".format(
        protocol="postgresql",
        user=postgres_output.user,
        password=postgres_output.password,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=postgres_output.database,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        cmd=[
            "/bin/sh", "-c", 
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start'
        ],
        env_vars={
            "ETHEREUM_JSONRPC_VARIANT": "geth",
            "ETHEREUM_JSONRPC_HTTP_URL": el_client_rpc_url,
            "ETHEREUM_JSONRPC_TRACE_URL": el_client_rpc_url,
            "DATABASE_URL": database_url,
            "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
            "ECTO_USE_SSL": "false",
            "NETWORK": "NETWORK",
            "SUBNETWORK": "Ritual Superchain",
            "BLOCKSCOUT_VERSION": "BLOCKSCOUT_VERSION",
            "PORT": "{}".format(HTTP_PORT_NUMBER),
        },
    )
