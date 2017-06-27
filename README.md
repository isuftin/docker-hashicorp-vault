# Hashicorp Vault HA Docker Configuration

## DynamoDB

DynamoDB is used in this project to provide the storage back-end for Vault which
allows Vault to work in High Availability (HA) mode.

The DynamoDB Docker container is built on top of the community container
[`cnadiminti/dynamodb-local`](https://hub.docker.com/r/cnadiminti/dynamodb-local/).
The main things that the version in this project adds
is the installation of the AWS CLI and adds a health check. Also, I've moved most
of the ENTRYPOINT from the original container configuration into a CMD so that it
may be overridden by the user (in this case, docker-compose).

More information about DynamoDB Local is available in the [AWS documentation](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)

#### Building the container

 Before building,
see the [Intercept SSL certificate](#dynamodb-intercept-ssl) section in order to
add your root certificate to the container.

To build, simply issue `docker-compose build dynamodb`

Once built, you will have an image named `vault_dynamodb`.

#### Running DynamoDB

Once you have DynamoDB built, you can simply run it by issuing `docker-compose up dynamodb`

You typically will not need to run DynamoDB standalone. If using Docker Compose,
starting the Vault container will also start DynamoDB.

#### Healthcheck

The DynamoDB container contains a healthcheck that uses the AWS CLI to perform a
list-tables command against DynamoDB. If the service is running, this should exit
cleanly with a 0 exit code.

You can check the health of the container via `docker ps`:

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                            PORTS                    NAMES
8d658d997c1b        vault_dynamodb      "java -Djava.libra..."   4 seconds ago       Up 3 seconds (health: starting)   0.0.0.0:8000->8000/tcp   vault_dynamod

$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                    PORTS                    NAMES
8d658d997c1b        vault_dynamodb      "java -Djava.libra..."   32 seconds ago      Up 31 seconds (healthy)   0.0.0.0:8000->8000/tcp   vault_dynamodb
```

A health check happens every 30 seconds.

#### Environment variables

- DYNAMODB_PORT: (int: 8000) Sets the port that DynamoDB listens on
- DYNAMODB_CORS: (str: '\*') Sets the CORS configuration for DYnamoDB

#### Data persistence

Docker Compose configures the DynamoDB container to persist data to a Docker volume
named `dynamodb-volume`. This persists DynamoDB configuration and data between
container restarts or rebuilds. To remove the volume once the container is removed,
once the DynamoDB container is stopped and removed, run the following command:
`docker volume ls --filter label=gov.usgs.wma.docker.name=volume.dynamodb --format "{{.Name}}"`

Use the output of this command in `docker volume rm <output>`:

```
$ docker volume ls --filter label=gov.usgs.wma.docker.name=volume.dynamodb --format "{{.Name}}"
dockerhashicorpvault_dynamodb-volume
$ docker volume rm dockerhashicorpvault_dynamodb-volume
dockerhashicorpvault_dynamodb-volume
$ docker volume ls --filter label=gov.usgs.wma.docker.name=volume.dynamodb --format "{{.Name}}"
$
```  
Note that after re-running the `docker volume ls` command, it comes up empty
Alternatively, you can simply issue the following:
```
$ docker volume rm $(docker volume ls --filter label=gov.usgs.wma.docker.name=volume.dynamodb --format "{{.Name}}")
dockerhashicorpvault_dynamodb-volume
$ docker volume ls --filter label=gov.usgs.wma.docker.name=volume.dynamodb --format "{{.Name}}"
$
```

### CLI access to DynamoDB

The DynamoDB is configured with AWS installed. You can use the containerized AWS
commandline client against DynamoDB from outside of the container if you wish.

Here is an example of doing so:
```
$ docker exec -t vault_dynamodb aws dynamodb list-tables --endpoint-url http://127.0.0.1:8000
{
    "TableNames": [
        "vault-data"
    ]
}
```

You should also be able to configure your local AWS client to point to the containerized
DynamoDB service. You would just need to set the following env vars on your host:

- AWS_ACCESS_KEY_ID: anything
- AWS_SECRET_ACCESS_KEY: anything
- AWS_DEFAULT_REGION: us-east-1

In the command line, set the endpoint-url IP to the IP of your Docker Machine VM
(use the `docker-machine ip` command to discover the IP). So the above command on
your local host would look like (assuming your Docker Machine VM name is vault-dev):

    $ docker exec -t vault_dynamodb aws dynamodb list-tables --endpoint-url http://`docker-machine ip vault-dev`:8000


#### <a name="dynamodb-intercept-ssl)"></a>Intercept SSL certificate

Add your SSL root certificate into `dynamodb/data/certs/root.pem` when building the
Docker container. This allows the container to use your corporate SSL intercept
certificate to pull from Python repositories to upgrade pip and install the AWS
commandline client.
