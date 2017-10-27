# Hashicorp Vault HA Docker Configuration

# Consul

Vault HA will use Consul as the high availability back-end for clustering purposes.

#### Creating certificates for TLS

The wildcard certificates included in this project are to allow Consul to operate using SSL. You probably will not need to alter anything here but in any case, this is how they were created. In order to follow along, you will need openssl installed on your system.

I've added a custom openssl.conf file into the `consul/data/certificates` directory. This configuration is necessary to create a Certificate Authority cert as well as provide the necessary openssl extensions required by Consul in order to work over TLS.

```bash
$ cd consul/data/certificates
$ touch certindex
$ echo 000a > serial
$ mkdir certs
$ SUBJ="/C=US/ST=Wisconsin/L=Middleon/O=US Geological Survey/OU=WMA/CN=server.docker_dc.consul"
$ openssl req -newkey rsa:2048 -days 9999  -x509 -nodes -out consul-root.cer -keyout consul-private.pem -subj $SUBJ
$ openssl req -newkey rsa:1024 -nodes -out consul-server.csr -keyout consul-server.key -subj $SUBJ
$ openssl ca -batch -config openssl.conf -notext -in consul-server.csr -out consul-server.cer
```

Note that the Common Name (CN) in the above configuration has the servers as `server.docker_dc.consul`. Consul expects servers to have their names as
server.&lt;datacenter name&gt;.consul. The datacenter name is configured in the configuration files in `consul/data/node[1-3]_config.json`. If you change the data center name there, you will want to regenerate the certificates to match.

NOTE: I've also included a script to automate the production of these SSL scripts. In Linux or MacOS, you can change your current working directory to `consul/data/certificates`. Next, you will add the executable bit to the shell script by issuing `chmod +x create_certificates.sh`. If you want to set your own subject for the certificates, create an environment variable named `SUBJ` and assign the subject to it like so: `SUBJ="/C=US/ST=Wisconsin/L=Middleon/O=US Geological Survey/OU=WMA/CN=server.docker_dc.consul"`. If you don't set a subject yourself, the subject will be that which is shown here as default. Finally, run the script by issuing `./create_certificates.sh`

tl;dr:
```bash
$ cd consul/data/certificates
$ chmod +x create_certificates.sh
$ SUBJ="/C=US/ST=New York/L=Brooklyn/O=My Company Name/OU=My Company Division/CN=server.docker_dc.consul"
$ ./create_certificates.sh
```

#### Starting Consul Cluster

When starting the Vault containers, they should automatically kick off the Consul containers. But if you wish to work with Consul directly, you should be able to simply issue `docker-compose up consul_node_1 consul_node_2 consul_node_3`

When the containers start, they will self-elect a leader between themselves after
they've all connected to one another. You'll know that a leader has been elected
when you see output in the Docker Compose logs that looks similar to:

```
[...]
vault_consul_node1 |     2017/06/28 13:12:41 [INFO] consul: member 'node_1' joined, marking health alive
vault_consul_node1 |     2017/06/28 13:12:41 [INFO] consul: member 'node_3' joined, marking health alive
vault_consul_node1 |     2017/06/28 13:12:41 [INFO] consul: member 'node_2' joined, marking health alive
vault_consul_node3 |     2017/06/28 13:12:41 [INFO] consul: New leader elected: node_1
vault_consul_node2 |     2017/06/28 13:12:41 [INFO] consul: New leader elected: node_1
```

You should also be able to go to the web UI of any of these containers.

The containers advertise their UI at different HTTP and HTTPS ports in order to avoid collision
on the host.

The ports are:

- Node 1
  - HTTP: 8500
  - HTTPS: 8700
- Node 2
  - HTTP: 8501
  - HTTPS: 8701
- Node 3
  - HTTP: 8502
  - HTTPS: 8702

After finding out the IP of the Docker Machine VM (`docker-machine ip <machine name>`),
you can point your browser to the IP of the VM and the node you wish to view. For
example, if the IP of the Docker Machine is 192.168.99.100 and you want to view
the UI for node 2, you would point your browser to http://192.168.99.100:8501/ui/ or https://192.168.99.100:8701/ui/

# Vault

#### Creating certificates for TLS

```
$ openssl genrsa -out vault/data/certs/wildcard.key 2048
$ openssl req -nodes -newkey rsa:2048 -keyout vault/data/certs/wildcard.key -out vault/data/certs/wildcard.csr -subj "/C=US/ST=Wisconsin/L=Middleon/O=US Geological Survey/OU=WMA/CN=*.container"
$ openssl x509 -req -days 9999 -in vault/data/certs/wildcard.csr -signkey vault/data/certs/wildcard.key  -out vault/data/certs/wildcard.crt
```

#### Starting the Vault cluster

Once you have the Consul cluster and DynamoDB up, you can start the Vault cluster:

`$ docker-compose up vault1 vault2 vault3`

In another terminal, you can check the running containers and see something similar
to this:

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS                                                                                              NAMES
49cf7f253e52        vault_dev           "docker-entrypoint..."   36 seconds ago      Up 25 seconds (healthy)     0.0.0.0:8125->8125/tcp, 0.0.0.0:8200-8201->8200-8201/tcp                                           vault1
a0a1040b7c65        vault_dev           "docker-entrypoint..."   36 seconds ago      Up 25 seconds (healthy)     0.0.0.0:8126->8125/tcp, 0.0.0.0:8202->8200/tcp, 0.0.0.0:8203->8201/tcp                             vault2
e8c1b04abc97        vault_dev           "docker-entrypoint..."   37 seconds ago      Up 25 seconds (unhealthy)   0.0.0.0:8127->8125/tcp, 0.0.0.0:8204->8200/tcp, 0.0.0.0:8205->8201/tcp                             vault3
2918868627f7        consul:0.8.5        "docker-entrypoint..."   42 seconds ago      Up 38 seconds               8300-8302/tcp, 8301-8302/udp, 8600/tcp, 8600/udp, 0.0.0.0:8701->8701/tcp, 0.0.0.0:8501->8500/tcp   vault_consul_node2
ac8a82cc4dec        consul:0.8.5        "docker-entrypoint..."   42 seconds ago      Up 38 seconds               8300-8302/tcp, 8301-8302/udp, 8600/tcp, 8600/udp, 0.0.0.0:8702->8702/tcp, 0.0.0.0:8502->8500/tcp   vault_consul_node3
f4c9a0a2cc94        vault_dynamodb      "java -Djava.libra..."   42 seconds ago      Up 39 seconds (healthy)     0.0.0.0:8000->8000/tcp                                                                             vault_dynamodb
b5cd8b5cf5b6        consul:0.8.5        "docker-entrypoint..."   42 seconds ago      Up 39 seconds               8300-8302/tcp, 8301-8302/udp, 0.0.0.0:8500->8500/tcp, 8600/tcp, 8600/udp, 0.0.0.0:8700->8700/tcp   vault_consul_node1
```

#### Initializing

When the Vault cluster has started, you can issue the command `docker exec -it vault1 vault init`

This performs the init command using the vault commandline utility in the running vault1
container:

```
$ docker exec -t vault1 vault init
Unseal Key 1: wQ3k2eM8gkg6b/Qq08rWnrTT9YTtE08M8ikjXEvlBCqk
Unseal Key 2: FHmnqZfUpsDr8fttSvLhsMsi6y13e5WDWcvE8WMFFIxN
Unseal Key 3: Zmt9VXdghSzvY7xKps3xzfS5Korcn8oG8ULo+XlWWJAP
Unseal Key 4: BZeUk2RtW4JXHc9ttXl9DjvG22Fu99S7Uvxv//cThif5
Unseal Key 5: gKol46XhdVQPxFmDyRZ8dNS4ekP83avp72QVx8KGbq6w
Initial Root Token: c62c77ea-211e-0845-1ae7-cc58c714f8a2

Vault initialized with 5 keys and a key threshold of 3. Please
securely distribute the above keys. When the vault is re-sealed,
restarted, or stopped, you must provide at least 3 of these keys
to unseal it again.

Vault does not store the master key. Without at least 3 keys,
your vault will remain permanently sealed.
```

You will want to copy down the unseal keys and the root token.  

#### Unsealing

The vault server cluster is initially sealed. This means that no secrets may be
written or read.

```
$  docker exec -t vault1 vault status
Sealed: true
Key Shares: 5
Key Threshold: 3
Unseal Progress: 0
Unseal Nonce:
Version: 0.7.3

High-Availability Enabled: true
        Mode: sealed
```

In order to unseal a vault, you need to perform the unseal command using 3 of the 5
unseal keys that are given during init. You have to do this for each Vault server
in the cluster.

To unseal any single vault server, you can issue the following command using 3
unseal keys:

`$ docker exec -t vault1 vault unseal <unseal key>`

After doing this three times with 3 unseal keys, a vault will be unsealed and ready
for action. Now you need to do the same thing for the other vault servers in the
cluster.

Certainly, that's a chore. In order to speed up the process,
I've included a short bash script which unseals all the vaults and authenticates
you to the vault servers using the root token.

The shell script sits in `vault/unseal.sh`. You can simply perform the following:

```
$ vault/unseal.sh \
  <unseal key 1> \
  <unseal key 2> \
  <unseal key 3> \
  <unseal key 4> \
  <unseal key 5> \
  <root key>

[ ... lots of vault interaction output ... ]

$ docker exec -it vault1 vault status

Sealed: false
Key Shares: 5
Key Threshold: 3
Unseal Progress: 0
Unseal Nonce:
Version: 0.7.3
Cluster Name: testcluster
Cluster ID: 02ffafa8-759b-bee5-a40c-3c7770925e1c

High-Availability Enabled: true
        Mode: active
        Leader: https://vault1.container:8200
```

# DynamoDB

### Note: DynamoDB is not currently being used in the configuration for this project. Consul is what is currently being used.

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

The DynamoDB is configured with AWS cli installed. You can use the containerized AWS
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

    $ aws dynamodb list-tables --endpoint-url http://`docker-machine ip vault-dev`:8000


#### <a name="dynamodb-intercept-ssl)"></a>Intercept SSL certificate

Add your SSL root certificate into `dynamodb/data/certs/root.pem` when building the
Docker container. This allows the container to use your corporate SSL intercept
certificate to pull from Python repositories to upgrade pip and install the AWS
commandline client.
