# frp client and server toml generate automatic

i use frp in local machine(frpc) and server(frps), always use "http" type toml in client and server and frpc or frps -c xxx.toml.
please give me a shell script to generate it.

## shell information
```shell
frpg.sh [command] [flag]
Available Commands:
 server|client generat a toml for frps or frpc, must give one
 start optional, if gived, execte frpc -c {name}.toml or frps -c {name}.toml

Flags:
 -n, --name             string      the proxies name
 -t, --type             string      the proxies type, offen 'http' or 'tcp', optional and default 'http'
 -lp, --localPort       integer     the frp client local port need be proxies
 -sp, --serverPort      interget    the frp server port used to proxies
 -sa, --serverAddr      string      the frp server ip address, default gave in conf/frpg.conf
 -cd, --customDomains   string      same with frp server ip address, default gave in conf/frpg.conf
 -h, --help                         print help text
 -v, --version                      print "frp generator v1.0 developed by tiankx1003"
 
Use "frpg [command] --help" for more information about a frp generator.
```

## directory architecture
```
├── conf
│   └── frpg.conf
├── bin
│   ├── frpg
│   ├── frpc
│   └── frps
├── log
│   ├── {name}-{localPort}-client.log
│   └── {name}-{serverPort}-server.log
└── toml
    ├── {name}-{localPort}-client.toml
    └── {name}-{serverPort}-server.toml
```

## expect
when i execute `bin/frpg client -n minikube -lp 37549 -sp 7003` got a file `toml/minikube-37549-client.toml` like this
```toml
[[proxies]]
name = "minikube"
type = "http"
localPort = 37549
customDomains = ["melina"]
serverAddr = "melina"
serverPort = 7003
```
if i execute `bin/frpg client start -n minikube -lp 37549 -sp 7003` will got a file `toml/minikube-37549-client.toml` and execute `bin/frpc -c toml/minikube-37549-client.toml` automatic.

when i execute `bin/frpg server -n minikube -lp 37549 -sp 7003` got a file `toml/minikube-7003-server.toml` like this
```toml
vhostHTTPPort = 37549
bindPort = 7003
```
if i execute `bin/frpg server start -n minikube -lp 37549 -sp 7003` will got a file `toml/minikube-7003-server.toml` and execute `bin/frps -c toml/minikube-7003-server.toml` automatic.

bin/frpg client -n doris -lp 8030 -sp 7001
bin/frpg client -n grafana -lp 3000 -sp 7002
bin/frpg client -n minio -lp 9001 -sp 7003
bin/frpg client -n flink -lp 8081 -sp 7004
bin/frpg client -n dinky -lp 8888 -sp 7005
bin/frpg client -n k8s_api -lp 6443 -sp 7006

## Best Impl
```shell
#!/bin/bash

# Function to print help text
print_help() {
    echo "Usage: frpg.sh [command] [flags]"
    echo "Available Commands:"
    echo "  server         Generate a TOML file for frps"
    echo "  client         Generate a TOML file for frpc"
    echo "Flags:"
    echo "  -n, --name             string      The proxy's name"
    echo "  -t, --type             string      The proxy's type, often 'http' or 'tcp' (optional, default: 'http')"
    echo "  -lp, --localPort       integer     The frp client local port to be proxied"
    echo "  -sp, --serverPort      integer     The frp server port used for proxying"
    echo "  -sa, --serverAddr      string      The frp server IP address (default from conf/frpg.conf)"
    echo "  -cd, --customDomains   string      Custom domains (same with frp server IP address, default from conf/frpg.conf)"
    echo "  -h, --help                         Print help text"
    echo "  -v, --version                      Print 'frp generator v1.0 developed by tiankx1003'"
    exit 0
}

# Function to generate the client TOML file
generate_client_toml() {
    cat > "toml/$name-client-$localPort.toml" << EOF
serverAddr = "melina"
serverPort = $serverPort

[[proxies]]
name = "$name"
type = "http"
localPort = $localPort
customDomains = ["melina"]
EOF
}

# Function to generate the server TOML file
generate_server_toml() {
    cat > "toml/$name-server-$serverPort.toml" << EOF
vhostHTTPPort = $localPort
bindPort = $serverPort
EOF
}

# Function to start the client or server
start_service() {
    if [ "$1" == "client" ]; then
        generate_client_toml
#        ./bin/frpc -c "toml/$name-$localPort-client.toml"
    elif [ "$1" == "server" ]; then
        generate_server_toml
#        ./bin/frps -c "toml/$name-$serverPort-server.toml"
    else
        echo "Invalid command."
        print_help
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        server|client)
            command="$1"
            shift
            ;;
        -n|--name)
            name="$2"
            shift
            shift
            ;;
        -t|--type)
            type="$2"
            shift
            shift
            ;;
        -lp|--localPort)
            localPort="$2"
            shift
            shift
            ;;
        -sp|--serverPort)
            serverPort="$2"
            shift
            shift
            ;;
        -sa|--serverAddr)
            serverAddr="$2"
            shift
            shift
            ;;
        -cd|--customDomains)
            customDomains="$2"
            shift
            shift
            ;;
        -h|--help)
            print_help
            ;;
        -v|--version)
            echo "frp generator v1.0 developed by tiankx1003"
            exit 0
            ;;
        *)
            echo "Unknown flag: $1"
            print_help
            ;;
    esac
done

# Check if command and required flags are provided
if [ -z "$command" ]; then
    echo "Command not provided."
    print_help
fi
if [ "$command" == "client" ]; then
    if [ -z "$name" ] || [ -z "$localPort" ] || [ -z "$serverPort" ]; then
        echo "Missing required flags for client command."
        print_help
    fi
elif [ "$command" == "server" ]; then
    if [ -z "$name" ] || [ -z "$localPort" ] || [ -z "$serverPort" ]; then
        echo "Missing required flags for server command."
        print_help
    fi
fi

# Start the service if start flag is provided
start_service "$command"
```