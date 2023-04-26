* [Overview](#overview)
* [Functionality](#functionality)
* [Recommended System Requirements](#recommended-system-requirements)
* [Running Docker Image](#running-docker-image)
* [Configuring Docker Image](#configuring-docker-image)
    - [Storing Data](#storing-data)
    - [Running ONLYOFFICE Document Server on Different Port](#running-onlyoffice-document-server-on-different-port)
    - [Running ONLYOFFICE Document Server using HTTPS](#running-onlyoffice-document-server-using-https)
        + [Generation of Self Signed Certificates](#generation-of-self-signed-certificates)
        + [Strengthening the Server Security](#strengthening-the-server-security)
        + [Installation of the SSL Certificates](#installation-of-the-ssl-certificates)
        + [Available Configuration Parameters](#available-configuration-parameters)
* [Installing ONLYOFFICE Document Server integrated with Community and Mail Servers](#installing-onlyoffice-document-server-integrated-with-community-and-mail-servers)
* [Issues](#issues)
    - [Docker Issues](#docker-issues)
    - [Document Server usage Issues](#document-server-usage-issues)
* [Project Information](#project-information)
* [User Feedback and Support](#user-feedback-and-support)

## Overview

ONLYOFFICE Document Server is an online office suite comprising viewers and editors for texts, spreadsheets and presentations, fully compatible with Office Open XML formats: .docx, .xlsx, .pptx and enabling collaborative editing in real time.

Starting from version 6.0, Document Server is distributed as ONLYOFFICE Docs. It has [three editions](https://github.com/ONLYOFFICE/DocumentServer#onlyoffice-document-server-editions). With this image, you will install the free Community version. 

ONLYOFFICE Docs can be used as a part of ONLYOFFICE Workspace or with third-party sync&share solutions (e.g. Nextcloud, ownCloud, Seafile) to enable collaborative editing within their interface.

***Important*** Please update `docker-enginge` to latest version (`20.10.21` as of writing this doc) before using it. We use `ubuntu:22.04` as base image and it older versions of docker have compatibility problems with it

## Functionality ##
* ONLYOFFICE Document Editor
* ONLYOFFICE Spreadsheet Editor
* ONLYOFFICE Presentation Editor
* ONLYOFFICE Documents application for iOS
* Collaborative editing
* Hieroglyph support
* Support for all the popular formats: DOC, DOCX, TXT, ODT, RTF, ODP, EPUB, ODS, XLS, XLSX, CSV, PPTX, HTML

Integrating it with ONLYOFFICE Community Server you will be able to:
* view and edit files stored on Drive, Box, Dropbox, OneDrive, OwnCloud connected to ONLYOFFICE;
* share files;
* embed documents on a website;
* manage access rights to documents.

## Recommended System Requirements

* **RAM**: 4 GB or more
* **CPU**: dual-core 2 GHz or higher
* **Swap**: at least 2 GB
* **HDD**: at least 2 GB of free space
* **Distribution**: 64-bit Red Hat, CentOS or other compatible distributive with kernel version 3.8 or later, 64-bit Debian, Ubuntu or other compatible distributive with kernel version 3.8 or later
* **Docker**: version 1.9.0 or later

## Running Docker Image

    sudo docker run -i -t -d -p 80:80 onlyoffice/documentserver

Use this command if you wish to install ONLYOFFICE Document Server separately. To install ONLYOFFICE Document Server integrated with Community and Mail Servers, refer to the corresponding instructions below.

## Configuring Docker Image

### Storing Data

All the data are stored in the specially-designated directories, **data volumes**, at the following location:
* **/var/log/onlyoffice** for ONLYOFFICE Document Server logs
* **/var/www/onlyoffice/Data** for certificates
* **/var/lib/onlyoffice** for file cache
* **/var/lib/postgresql** for database

To get access to your data from outside the container, you need to mount the volumes. It can be done by specifying the '-v' option in the docker run command.

    sudo docker run -i -t -d -p 80:80 \
        -v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice  \
        -v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  \
        -v /app/onlyoffice/DocumentServer/lib:/var/lib/onlyoffice \
        -v /app/onlyoffice/DocumentServer/rabbitmq:/var/lib/rabbitmq \
        -v /app/onlyoffice/DocumentServer/redis:/var/lib/redis \
        -v /app/onlyoffice/DocumentServer/db:/var/lib/postgresql  onlyoffice/documentserver

Normally, you do not need to store container data because the container's operation does not depend on its state. Saving data will be useful:
* For easy access to container data, such as logs
* To remove the limit on the size of the data inside the container
* When using services launched outside the container such as PostgreSQL, Redis, RabbitMQ

### Running ONLYOFFICE Document Server on Different Port

To change the port, use the -p command. E.g.: to make your portal accessible via port 8080 execute the following command:

    sudo docker run -i -t -d -p 8080:80 onlyoffice/documentserver

### Running ONLYOFFICE Document Server using HTTPS

        sudo docker run -i -t -d -p 443:443 \
        -v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  onlyoffice/documentserver

Access to the onlyoffice application can be secured using SSL so as to prevent unauthorized access. While a CA certified SSL certificate allows for verification of trust via the CA, a self signed certificates can also provide an equal level of trust verification as long as each client takes some additional steps to verify the identity of your website. Below the instructions on achieving this are provided.

To secure the application via SSL basically two things are needed:

- **Private key (.key)**
- **SSL certificate (.crt)**

So you need to create and install the following files:

        /app/onlyoffice/DocumentServer/data/certs/tls.key
        /app/onlyoffice/DocumentServer/data/certs/tls.crt

When using CA certified certificates (e.g [Let's encrypt](https://letsencrypt.org)), these files are provided to you by the CA. If you are using self-signed certificates you need to generate these files [yourself](#generation-of-self-signed-certificates).

#### Using the automatically generated Let's Encrypt SSL Certificates

        sudo docker run -i -t -d -p 80:80 -p 443:443 \
        -e LETS_ENCRYPT_DOMAIN=your_domain -e LETS_ENCRYPT_MAIL=your_mail  onlyoffice/documentserver

If you want to get and extend Let's Encrypt SSL Certificates automatically just set LETS_ENCRYPT_DOMAIN and LETS_ENCRYPT_MAIL variables.

#### Generation of Self Signed Certificates

Generation of self-signed SSL certificates involves a simple 3 step procedure.

**STEP 1**: Create the server private key

```bash
openssl genrsa -out tls.key 2048
```

**STEP 2**: Create the certificate signing request (CSR)

```bash
openssl req -new -key tls.key -out tls.csr
```

**STEP 3**: Sign the certificate using the private key and CSR

```bash
openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt
```

You have now generated an SSL certificate that's valid for 365 days.

#### Strengthening the server security

This section provides you with instructions to [strengthen your server security](https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html).
To achieve this you need to generate stronger DHE parameters.

```bash
openssl dhparam -out dhparam.pem 2048
```

#### Installation of the SSL Certificates

Out of the four files generated above, you need to install the `tls.key`, `tls.crt` and `dhparam.pem` files at the onlyoffice server. The CSR file is not needed, but do make sure you safely backup the file (in case you ever need it again).

The default path that the onlyoffice application is configured to look for the SSL certificates is at `/var/www/onlyoffice/Data/certs`, this can however be changed using the `SSL_KEY_PATH`, `SSL_CERTIFICATE_PATH` and `SSL_DHPARAM_PATH` configuration options.

The `/var/www/onlyoffice/Data/` path is the path of the data store, which means that you have to create a folder named certs inside `/app/onlyoffice/DocumentServer/data/` and copy the files into it and as a measure of security you will update the permission on the `tls.key` file to only be readable by the owner.

```bash
mkdir -p /app/onlyoffice/DocumentServer/data/certs
cp tls.key /app/onlyoffice/DocumentServer/data/certs/
cp tls.crt /app/onlyoffice/DocumentServer/data/certs/
cp dhparam.pem /app/onlyoffice/DocumentServer/data/certs/
chmod 400 /app/onlyoffice/DocumentServer/data/certs/tls.key
```

You are now just one step away from having our application secured.

#### Available Configuration Parameters

*Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command.*

Below is the complete list of parameters that can be set using environment variables.

- **ONLYOFFICE_HTTPS_HSTS_ENABLED**: Advanced configuration option for turning off the HSTS configuration. Applicable only when SSL is in use. Defaults to `true`.
- **ONLYOFFICE_HTTPS_HSTS_MAXAGE**: Advanced configuration option for setting the HSTS max-age in the onlyoffice nginx vHost configuration. Applicable only when SSL is in use. Defaults to `31536000`.
- **SSL_CERTIFICATE_PATH**: The path to the SSL certificate to use. Defaults to `/var/www/onlyoffice/Data/certs/tls.crt`.
- **SSL_KEY_PATH**: The path to the SSL certificate's private key. Defaults to `/var/www/onlyoffice/Data/certs/tls.key`.
- **SSL_DHPARAM_PATH**: The path to the Diffie-Hellman parameter. Defaults to `/var/www/onlyoffice/Data/certs/dhparam.pem`.
- **SSL_VERIFY_CLIENT**: Enable verification of client certificates using the `CA_CERTIFICATES_PATH` file. Defaults to `false`
- **DB_TYPE**: The database type. Supported values are `postgres`, `mariadb` or `mysql`. Defaults to `postgres`.
- **DB_HOST**: The IP address or the name of the host where the database server is running.
- **DB_PORT**: The database server port number.
- **DB_NAME**: The name of a database to use. Should be existing on container startup.
- **DB_USER**: The new user name with superuser permissions for the database account.
- **DB_PWD**: The password set for the database account.
- **AMQP_URI**: The [AMQP URI](https://www.rabbitmq.com/uri-spec.html "RabbitMQ URI Specification") to connect to message broker server.
- **AMQP_TYPE**: The message broker type. Supported values are `rabbitmq` or `activemq`. Defaults to `rabbitmq`.
- **REDIS_SERVER_HOST**: The IP address or the name of the host where the Redis server is running.
- **REDIS_SERVER_PORT**:  The Redis server port number.
- **REDIS_SERVER_PASS**: The Redis server password. The password is not set by default.
- **NGINX_WORKER_PROCESSES**: Defines the number of nginx worker processes.
- **NGINX_WORKER_CONNECTIONS**: Sets the maximum number of simultaneous connections that can be opened by a nginx worker process.
- **SECURE_LINK_SECRET**: Defines secret for the nginx config directive [secure_link_md5](https://nginx.org/en/docs/http/ngx_http_secure_link_module.html#secure_link_md5). Defaults to `random string`.
- **JWT_ENABLED**: Specifies the enabling the JSON Web Token validation by the ONLYOFFICE Document Server. Defaults to `true`.
- **JWT_SECRET**: Defines the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Document Server. Defaults to random value.
- **JWT_HEADER**: Defines the http header that will be used to send the JSON Web Token. Defaults to `Authorization`.
- **JWT_IN_BODY**: Specifies the enabling the token validation in the request body to the ONLYOFFICE Document Server. Defaults to `false`.
- **WOPI_ENABLED**: Specifies the enabling the wopi handlers. Defaults to `false`.
- **USE_UNAUTHORIZED_STORAGE**: Set to `true`if using selfsigned certificates for your storage server e.g. Nextcloud. Defaults to `false`
- **GENERATE_FONTS**: When 'true' regenerates fonts list and the fonts thumbnails etc. at each start. Defaults to `true`
- **METRICS_ENABLED**: Specifies the enabling StatsD for ONLYOFFICE Document Server. Defaults to `false`.
- **METRICS_HOST**: Defines StatsD listening host. Defaults to `localhost`.
- **METRICS_PORT**: Defines StatsD listening port. Defaults to `8125`.
- **METRICS_PREFIX**: Defines StatsD metrics prefix for backend services. Defaults to `ds.`.
- **LETS_ENCRYPT_DOMAIN**: Defines the domain for Let's Encrypt certificate.
- **LETS_ENCRYPT_MAIL**: Defines the domain administator mail address for Let's Encrypt certificate.

## Installing ONLYOFFICE Document Server integrated with Community and Mail Servers

ONLYOFFICE Document Server is a part of ONLYOFFICE Community Edition that comprises also Community Server and Mail Server. To install them, follow these easy steps:

**STEP 1**: Create the `onlyoffice` network.

```bash
docker network create --driver bridge onlyoffice
```
Then launch containers on it using the 'docker run --net onlyoffice' option:

**STEP 2**: Install MySQL.

Follow [these steps](#installing-mysql) to install MySQL server.

**STEP 3**: Generate JWT Secret

JWT secret defines the secret key to validate the JSON Web Token in the request to the **ONLYOFFICE Document Server**. You can specify it yourself or easily get it using the command:
```
JWT_SECRET=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 12);
```

**STEP 4**: Install ONLYOFFICE Document Server.

```bash
sudo docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-document-server \
 -e JWT_ENABLED=true \
 -e JWT_SECRET=${JWT_SECRET} \
 -e JWT_HEADER=AuthorizationJwt \
 -v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice  \
 -v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  \
 -v /app/onlyoffice/DocumentServer/lib:/var/lib/onlyoffice \
 -v /app/onlyoffice/DocumentServer/db:/var/lib/postgresql \
 onlyoffice/documentserver
```

**STEP 5**: Install ONLYOFFICE Mail Server. 

For the mail server correct work you need to specify its hostname 'yourdomain.com'.

```bash
sudo docker run --init --net onlyoffice --privileged -i -t -d --restart=always --name onlyoffice-mail-server -p 25:25 -p 143:143 -p 587:587 \
 -e MYSQL_SERVER=onlyoffice-mysql-server \
 -e MYSQL_SERVER_PORT=3306 \
 -e MYSQL_ROOT_USER=root \
 -e MYSQL_ROOT_PASSWD=my-secret-pw \
 -e MYSQL_SERVER_DB_NAME=onlyoffice_mailserver \
 -v /app/onlyoffice/MailServer/data:/var/vmail \
 -v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver \
 -v /app/onlyoffice/MailServer/logs:/var/log \
 -h yourdomain.com \
 onlyoffice/mailserver
```

The additional parameters for mail server are available [here](https://github.com/ONLYOFFICE/Docker-CommunityServer/blob/master/docker-compose.workspace_enterprise.yml#L87).

To learn more, refer to the [ONLYOFFICE Mail Server documentation](https://github.com/ONLYOFFICE/Docker-MailServer "ONLYOFFICE Mail Server documentation").

**STEP 6**: Install ONLYOFFICE Community Server

```bash
sudo docker run --net onlyoffice -i -t -d --privileged --restart=always --name onlyoffice-community-server -p 80:80 -p 443:443 -p 5222:5222 --cgroupns=host \
 -e MYSQL_SERVER_ROOT_PASSWORD=my-secret-pw \
 -e MYSQL_SERVER_DB_NAME=onlyoffice \
 -e MYSQL_SERVER_HOST=onlyoffice-mysql-server \
 -e MYSQL_SERVER_USER=onlyoffice_user \
 -e MYSQL_SERVER_PASS=onlyoffice_pass \
 
 -e DOCUMENT_SERVER_PORT_80_TCP_ADDR=onlyoffice-document-server \
 -e DOCUMENT_SERVER_JWT_ENABLED=true \
 -e DOCUMENT_SERVER_JWT_SECRET=${JWT_SECRET} \
 -e DOCUMENT_SERVER_JWT_HEADER=AuthorizationJwt \
 
 -e MAIL_SERVER_API_HOST=${MAIL_SERVER_IP} \
 -e MAIL_SERVER_DB_HOST=onlyoffice-mysql-server \
 -e MAIL_SERVER_DB_NAME=onlyoffice_mailserver \
 -e MAIL_SERVER_DB_PORT=3306 \
 -e MAIL_SERVER_DB_USER=root \
 -e MAIL_SERVER_DB_PASS=my-secret-pw \
 
 -v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data \
 -v /app/onlyoffice/CommunityServer/logs:/var/log/onlyoffice \
 -v /app/onlyoffice/CommunityServer/letsencrypt:/etc/letsencrypt \
 -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
 onlyoffice/communityserver
```

Where `${MAIL_SERVER_IP}` is the IP address for **ONLYOFFICE Mail Server**. You can easily get it using the command:
```
MAIL_SERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' onlyoffice-mail-server)
```

Alternatively, you can use an automatic installation script to install the whole ONLYOFFICE Community Edition at once. For the mail server correct work you need to specify its hostname 'yourdomain.com'.

**STEP 1**: Download the Community Edition Docker script file

```bash
wget https://download.onlyoffice.com/install/opensource-install.sh
```

**STEP 2**: Install ONLYOFFICE Community Edition executing the following command:

```bash
bash opensource-install.sh -md yourdomain.com
```

Or, use [docker-compose](https://docs.docker.com/compose/install "docker-compose"). For the mail server correct work you need to specify its hostname 'yourdomain.com'. Assuming you have docker-compose installed, execute the following command:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/Docker-CommunityServer/master/docker-compose.groups.yml
docker-compose up -d
```

## Issues

### Docker Issues

As a relatively new project Docker is being worked on and actively developed by its community. So it's recommended to use the latest version of Docker, because the issues that you encounter might have already been fixed with a newer Docker release.

The known Docker issue with ONLYOFFICE Document Server with rpm-based distributives is that sometimes the processes fail to start inside Docker container. Fedora and RHEL/CentOS users should try disabling selinux with setenforce 0. If it fixes the issue then you can either stick with SELinux disabled which is not recommended by RedHat, or switch to using Ubuntu.

### Document Server usage issues

Due to the operational characteristic, **Document Server** saves a document only after the document has been closed by all the users who edited it. To avoid data loss, you must forcefully disconnect the **Document Server** users when you need to stop **Document Server** in cases of the application update, server reboot etc. To do that, execute the following script on the server where **Document Server** is installed:

```
sudo docker exec <CONTAINER> documentserver-prepare4shutdown.sh
```

Please note, that both executing the script and disconnecting users may take a long time (up to 5 minutes).

## Project Information

Official website: [https://www.onlyoffice.com](https://www.onlyoffice.com/?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDockerDS)

Code repository: [https://github.com/ONLYOFFICE/DocumentServer](https://github.com/ONLYOFFICE/DocumentServer "https://github.com/ONLYOFFICE/DocumentServer")

Docker Image: [https://github.com/ONLYOFFICE/Docker-DocumentServer](https://github.com/ONLYOFFICE/Docker-DocumentServer "https://github.com/ONLYOFFICE/Docker-DocumentServer")

License: [GNU AGPL v3.0](https://help.onlyoffice.com/products/files/doceditor.aspx?fileid=4358397&doc=K0ZUdlVuQzQ0RFhhMzhZRVN4ZFIvaHlhUjN2eS9XMXpKR1M5WEppUk1Gcz0_IjQzNTgzOTci0 "GNU AGPL v3.0")

Free version vs commercial builds comparison: https://github.com/ONLYOFFICE/DocumentServer#onlyoffice-document-server-editions

SaaS version: [https://www.onlyoffice.com/cloud-office.aspx](https://www.onlyoffice.com/cloud-office.aspx?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDockerDS)

## User Feedback and Support

If you have any problems with or questions about this image, please visit our official forum to find answers to your questions: [forum.onlyoffice.com][1] or you can ask and answer ONLYOFFICE development questions on [Stack Overflow][2].

  [1]: https://forum.onlyoffice.com
  [2]: https://stackoverflow.com/questions/tagged/onlyoffice
