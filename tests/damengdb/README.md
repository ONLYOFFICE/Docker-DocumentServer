## Stand Documentserver with damengdb

### How it works

#### ⚠ Only on the first run:

The first deployment of the stand requires the execution of ***two scripts*** to prepare the environment.

***First:*** It is necessary to obtain an image of the dameng db database. To do this, run the script:
	
	bash damengdb-get-image.sh

***Second:*** After the image is obtained, it is also necessary to obtain a binary DISQL files that is used for remote access to the database service. To do this, run the script:
	
	bash damengdb-get-disql.sh

### Deploy stand

After db image and disql binary is ready, you cant deploy stand with flexible develop-build number with simple command: 
	
	BUILD=<build-number-from-develop> docker compose up -d

Note: The build number must be set each time the stand is deployed with compose up.
