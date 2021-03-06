#!/bin/bash

installUtils () {
	echo "*********************************Installing WGET..."
	yum install -y wget
	
	echo "*********************************Installing Maven..."
	wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O 	/etc/yum.repos.d/epel-apache-maven.repo
	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then
		sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
	fi
	yum install -y apache-maven
	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then
		alternatives --install /usr/bin/java java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java 20000
		alternatives --install /usr/bin/javac javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac 20000
		alternatives --install /usr/bin/jar jar /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/jar 20000
		alternatives --auto java
		alternatives --auto javac
		alternatives --auto jar
		ln -s /usr/lib/jvm/java-1.8.0 /usr/lib/jvm/java
	fi
	
	echo "*********************************Installing GIT..."
	yum install -y git
	
	echo "*********************************Installing Docker..."
	echo " 				  *****************Installing Docker via Yum..."
	yum install -y docker
	
	echo " 				  *****************Configuring Docker Permissions..."
	groupadd docker
	gpasswd -a yarn docker
	echo " 				  *****************Registering Docker to Start on Boot..."
	service docker start
	chkconfig --add docker
	chkconfig docker on
	service prometheus stop
	chkconfig prometheus off
}

waitForAmbari () {
       	# Wait for Ambari
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
                TASKSTATUS="READY"
        else
               	AUTHSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep HTTP | grep -Po '( [0-9]+)'| grep -Po '([0-9]+)')
               	if [ "$AUTHSTATUS" == 403 ]; then
               	echo "THE AMBARI PASSWORD IS NOT SET TO: admin"
               	echo "RUN COMMAND: ambari-admin-password-reset, SET PASSWORD: admin"
               	exit 403
               	else
                TASKSTATUS="PENDING"
               	fi
       	fi
       	echo "Waiting for Ambari..."
        echo "Ambari Status... " $TASKSTATUS
        sleep 2
       	done
}

serviceExists () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"status" : ' | grep -Po '([0-9]+)')

       	if [ "$SERVICE_STATUS" == 404 ]; then
       		echo 0
       	else
       		echo 1
       	fi
}

getServiceStatus () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $SERVICE_STATUS
}

getComponentStatus () {
       	SERVICE=$1
       	COMPONENT=$2
       	COMPONENT_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE/components/$COMPONENT | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $COMPONENT_STATUS
}

startServiceIfReady () {
	SERVICE=$1
	SERVICE_STATUS=$(getServiceStatus $SERVICE)
	echo "*********************************Checking $SERVICE status..."
	if ! [[ $SERVICE_STATUS == STARTED || $SERVICE_STATUS == INSTALLED ]]; then
       	echo "*********************************$SERVICE is in a transitional state, waiting..."
       	waitForService $SERVICE
       	echo "*********************************$SERVICE has entered a ready state..."
	elif [[ $SERVICE_STATUS == INSTALLED ]]; then
       	startService $SERVICE
	else
       	echo "*********************************$SERVICE Service Started..."
	fi
}

getRegistryHost () {
       	REGISTRY_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY/components/REGISTRY_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $REGISTRY_HOST
}

getLivyHost () {
       	LIVY_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/SPARK2/components/LIVY2_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $LIVY_HOST
}

getHiveInteractiveServerHost () {
        HIVESERVER_INTERACTIVE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER_INTERACTIVE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_INTERACTIVE_HOST
}

getDruidBroker () {
        DRUID_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_BROKER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $DRUID_BROKER
}

getKafkaBroker () {
       	KAFKA_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/KAFKA/components/KAFKA_BROKER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $KAFKA_BROKER
}

getAtlasHost () {
       	ATLAS_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ATLAS/components/ATLAS_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $ATLAS_HOST
}

getNifiHost () {
       	NIFI_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI/components/NIFI_MASTER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

       	echo $NIFI_HOST
}

waitForService () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
        until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

waitForServiceToStart () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED ]]; then
        	until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

waitForNifiServlet () {
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
       		echo "*********************************Requesting Nifi Servlet Status from http://$NIFI_HOST:9090/nifi-api/controller..."
       		TASKSTATUS=$(curl -u admin:admin -i -X GET http://$NIFI_HOST:9090/nifi-api/controller | grep -Po 'OK')
       		if [ "$TASKSTATUS" == OK ]; then
               		LOOPESCAPE="true"
       		else
               		TASKSTATUS="PENDING"
       		fi
       		echo "*********************************Waiting for NIFI Servlet..."
       		echo "*********************************NIFI Servlet Status... " $TASKSTATUS
       		sleep 2
       	done
}

stopService () {
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Stopping Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == STARTED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Stop $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"INSTALLED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Stop $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Stop $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
        echo "*********************************$SERVICE Service Stopped..."
       	elif [ "$SERVICE_STATUS" == INSTALLED ]; then
       	echo "*********************************$SERVICE Service Stopped..."
       	fi
}

startService (){
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Start $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

startServiceAndComplete (){
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"INSTALL COMPLETE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

installSchemaRegistryService () {
       	
       	echo "*********************************Creating REGISTRY service..."
       	# Create Schema Registry service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY

       	sleep 2
       	echo "*********************************Adding REGISTRY SERVER component..."
       	# Add REGISTRY SERVER component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY/components/REGISTRY_SERVER

       	sleep 2
       	echo "*********************************Creating REGISTRY configuration..."

       	# Create and apply configuration
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME registry-common $ROOT_PATH/CloudBreakArtifacts/hdf-config/registry-config/registry-common.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME registry-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/registry-config/registry-env.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME registry-log4j $ROOT_PATH/CloudBreakArtifacts/hdf-config/registry-config/registry-log4j.json
		
       	echo "*********************************Adding REGISTRY SERVER role to Host..."
       	# Add REGISTRY_SERVER role to Ambari Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/REGISTRY_SERVER

       	sleep 30
       	echo "*********************************Installing REGISTRY Service"
       	# Install REGISTRY Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Schema Registry"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY | grep "id" | grep -Po '([0-9]+)')
		
		sleep 2       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Schema Registry"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY | grep "id" | grep -Po '([0-9]+)')
       		 	echo "*********************************AMBARI TaskID " $TASKID
       		done
       	fi
       	
       	echo "*********************************AMBARI TaskID " $TASKID
       	sleep 2
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
               	TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
               	if [ "$TASKSTATUS" == COMPLETED ]; then
                       	LOOPESCAPE="true"
               	fi
               	echo "*********************************Task Status" $TASKSTATUS
               	sleep 2
       	done
}

installStreamlineService () {
       	
       	echo "*********************************Creating STREAMLINE service..."
       	# Create Streamline service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/STREAMLINE

       	sleep 2
       	echo "*********************************Adding STREAMLINE SERVER component..."
       	# Add STREAMLINE SERVER component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/STREAMLINE/components/STREAMLINE_SERVER

       	sleep 2
       	echo "*********************************Creating STREAMLINE configuration..."

       	# Create and apply configuration
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME streamline-common $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-common.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME streamline-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-env.json

	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME streamline-log4j $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-log4j.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME streamline_jaas_conf $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline_jaas_conf.json
		
       	echo "*********************************Adding STREAMLINE SERVER role to Host..."
       	# Add STREAMLINE SERVER role to Ambari Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/STREAMLINE_SERVER

       	sleep 30
       	echo "*********************************Installing STREAMLINE Service"
       	# Install STREAMLINE Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install SAM"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/STREAMLINE | grep "id" | grep -Po '([0-9]+)')
		
		sleep 2       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install SAM"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/STREAMLINE | grep "id" | grep -Po '([0-9]+)')
       		 	echo "*********************************AMBARI TaskID " $TASKID
       		done
       	fi
       	
       	echo "*********************************AMBARI TaskID " $TASKID
       	sleep 2
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
               	TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
               	if [ "$TASKSTATUS" == COMPLETED ]; then
                       	LOOPESCAPE="true"
               	fi
               	echo "*********************************Task Status" $TASKSTATUS
               	sleep 2
       	done
}

installNifiService () {
       	echo "*********************************Creating NIFI service..."
       	# Create NIFI service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI

       	sleep 2
       	echo "*********************************Adding NIFI MASTER component..."
       	# Add NIFI Master component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI/components/NIFI_MASTER
		curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI/components/NIFI_CA
		
       	sleep 2
       	echo "*********************************Creating NIFI configuration..."

       	# Create and apply configuration
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-ambari-config $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-ambari-config.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-ambari-ssl-config $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-ambari-ssl-config.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-authorizers-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-authorizers-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-bootstrap-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-bootstrap-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-bootstrap-notification-services-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-bootstrap-notification-services-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-flow-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-flow-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-login-identity-providers-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-login-identity-providers-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-node-logback-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-node-logback-env.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-properties $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-properties.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-state-management-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-state-management-env.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-jaas-conf $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-jaas-conf.json
				
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME nifi-logsearch-conf $ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-config/nifi-logsearch-conf.json
		
       	echo "*********************************Adding NIFI MASTER role to Host..."
       	# Add NIFI Master role to Ambari Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/NIFI_MASTER

       	echo "*********************************Adding NIFI CA role to Host..."
		# Add NIFI CA role to Ambari Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/NIFI_CA

       	sleep 30
       	echo "*********************************Installing NIFI Service"
       	# Install NIFI Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Nifi"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI | grep "id" | grep -Po '([0-9]+)')
		
		sleep 2       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Nifi"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI | grep "id" | grep -Po '([0-9]+)')
       		 	echo "*********************************AMBARI TaskID " $TASKID
       		done
       	fi
       	
       	echo "*********************************AMBARI TaskID " $TASKID
       	sleep 2
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
               	TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
               	if [ "$TASKSTATUS" == COMPLETED ]; then
                       	LOOPESCAPE="true"
               	fi
               	echo "*********************************Task Status" $TASKSTATUS
               	sleep 2
       	done
}

installDruidService () {
       	
       	echo "*********************************Creating DRUID service..."
       	# Create Druid service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID

       	sleep 2
       	echo "*********************************Adding DRUID components..."
       	# Add DRUID BROKER component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_BROKER
		sleep 2
		# Add DRUID COORDINATOR component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_COORDINATOR
       	# Add DRUID HISTORICAL component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_HISTORICAL
       	# Add DRUID MIDDLEMANAGER component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_MIDDLEMANAGER
		# Add DRUID OVERLORD component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_OVERLORD
       	# Add DRUID ROUTER component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_ROUTER
       	# Add DRUID SUPERSET component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_SUPERSET
		
       	sleep 2
       	echo "*********************************Creating DRUID configuration..."

       	# Create and apply configuration
       	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-broker $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-broker.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-common $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-common.json

		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-coordinator $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-coordinator.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-env.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-historical $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-historical.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-log4j $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-log4j.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-logrotate $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-logrotate.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-middlemanager $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-middlemanager.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-overlord $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-overlord.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-router $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-router.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-superset-env $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-superset-env.json
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME druid-superset $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-superset.json
		
		export HOST1=$(getHostByPosition 1)
		export HOST2=$(getHostByPosition 2)
		export HOST3=$(getHostByPosition 3)			
		
       	echo "*********************************Adding DRUID BROKER role to Host..."
       	# Add DRUID BROKER role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST1/host_components/DRUID_BROKER
       	export DRUID_BROKER=$HOST1
       	
       	echo "*********************************Adding DRUID SUPERSET role to Host..."
       	# Add DRUID SUPERSET role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/DRUID_SUPERSET
       	
       	echo "*********************************Adding DRUID ROUTER role to Host..."
       	# Add DRUID BROKER role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST2/host_components/DRUID_ROUTER
       	
       	echo "*********************************Adding DRUID OVERLORD role to Host..."
       	# Add DRUID OVERLORD role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/DRUID_OVERLORD
       	
       	echo "*********************************Adding DRUID COORDINATOR role to Host..."
       	# Add DRUID COORDINATOR role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/DRUID_COORDINATOR
       	
       	echo "*********************************Adding DRUID HISTORICAL role to Host..."
       	# Add DRUID HISTORICAL role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST1/host_components/DRUID_HISTORICAL
		
		echo "*********************************Adding DRUID HISTORICAL role to Host..."
       	# Add DRUID HISTORICAL role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST2/host_components/DRUID_HISTORICAL
       	
       	echo "*********************************Adding DRUID HISTORICAL role to Host..."
       	# Add DRUID HISTORICAL role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST3/host_components/DRUID_HISTORICAL
       	
       	echo "*********************************Adding DRUID MIDDLEMANAGER role to Host..."
       	# Add DRUID MIDDLEMANAGER role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST1/host_components/DRUID_MIDDLEMANAGER
       	
       	echo "*********************************Adding DRUID MIDDLEMANAGER role to Host..."
       	# Add DRUID MIDDLEMANAGER role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST2/host_components/DRUID_MIDDLEMANAGER
       	
       	echo "*********************************Adding DRUID MIDDLEMANAGER role to Host..."
       	# Add DRUID MIDDLEMANAGER role to Host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$HOST3/host_components/DRUID_MIDDLEMANAGER

       	sleep 30
       	echo "*********************************Installing DRUID Service"
       	# Install DRUID Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Druid"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID | grep "id" | grep -Po '([0-9]+)')
		
		sleep 2       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Druid"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID | grep "id" | grep -Po '([0-9]+)')
       		 	echo "*********************************AMBARI TaskID " $TASKID
       		done
       	fi
       	
       	echo "*********************************AMBARI TaskID " $TASKID
       	sleep 2
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
               	TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
               	if [ "$TASKSTATUS" == COMPLETED ]; then
                       	LOOPESCAPE="true"
               	fi
               	echo "*********************************Task Status" $TASKSTATUS
               	sleep 2
       	done
}

instalHDFManagementPack () {
	wget http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/3.0.0.0/tars/hdf_ambari_mp/hdf-ambari-mpack-3.0.0.0-453.tar.gz
ambari-server install-mpack --mpack=hdf-ambari-mpack-3.0.0.0-453.tar.gz --verbose

	sleep 2
	ambari-server restart
	waitForAmbari
	sleep 2
}

getHostByPosition (){
	HOST_POSITION=$1
	HOST_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts|grep -Po '"host_name" : "[a-zA-Z0-9_\W]+'|grep -Po ' : "([^"]+)'|grep -Po '[^: "]+'|tail -n +$HOST_POSITION|head -1)
	
	echo $HOST_NAME
}

configureAmbariRepos (){	
	curl -u admin:admin -d @$ROOT_PATH/CloudBreakArtifacts/hdf-config/api-payload/repo_update.json -H "X-Requested-By: ambari" -X PUT http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/2.6/repository_versions/1
}

installMySQL (){
	yum remove -y mysql57-community*
	yum remove -y mysql56-server*
	yum remove -y mysql-community*
	rm -Rvf /var/lib/mysql

	yum install -y epel-release
	yum install -y libffi-devel.x86_64
	ln -s /usr/lib64/libffi.so.6 /usr/lib64/libffi.so.5

	yum install -y mysql-connector-java*
	ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar


	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then       	
		yum install -y mysql56-server
		service mysqld start
	else
		yum localinstall -y https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
		yum install -y mysql-community-server
		#yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-8.noarch.rpm
#yum install -y mysql-community-server
		systemctl start mysqld.service
	fi
	chkconfig --add mysqld
	chkconfig mysqld on
}

setupHDFDataStores (){
	mysql --execute="CREATE DATABASE registry"
	mysql --execute="CREATE DATABASE streamline"
	mysql --execute="CREATE DATABASE druid DEFAULT CHARACTER SET utf8"
	mysql --execute="CREATE DATABASE superset DEFAULT CHARACTER SET utf8"
	mysql --execute="CREATE USER 'registry'@'%' IDENTIFIED BY 'registry'"
	mysql --execute="CREATE USER 'streamline'@'%' IDENTIFIED BY 'streamline'"
	mysql --execute="CREATE USER 'druid'@'%' IDENTIFIED BY 'druid'"
	mysql --execute="CREATE USER 'superset'@'%' IDENTIFIED BY 'superset'"
	mysql --execute="GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION"
	mysql --execute="GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION"
	mysql --execute="GRANT ALL PRIVILEGES ON druid.* TO 'druid'@'%' WITH GRANT OPTION"
	mysql --execute="GRANT ALL PRIVILEGES ON superset.* TO 'superset'@'%' WITH GRANT OPTION"
	mysql --execute="FLUSH PRIVILEGES"
	mysql --execute="COMMIT"
}

configureHive () {

export HOST1=$(getHostByPosition 1)
export HOST2=$(getHostByPosition 2)
export HOST3=$(getHostByPosition 3)

echo "*********************************Configuring Hive..."
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hiveserver2-interactive-site hive.druid.broker.address.default $DRUID_BROKER:8082
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hiveserver2-interactive-site hive.exec.post.hooks org.apache.hadoop.hive.ql.hooks.ATSHook,org.apache.atlas.hive.hook.HiveHook
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hiveserver2-interactive-site hive.exec.pre.hooks org.apache.hadoop.hive.ql.hooks.ATSHook
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hiveserver2-interactive-site hive.service.metrics.file.location /var/log/hive/hiveserver2Interactive-report.json
sleep 1

/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive_heapsize 2048
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.auto.convert.join.noconditionaltask.size 858783744
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.llap.daemon.num.executors 4
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.llap.daemon.queue.name llap
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.llap.daemon.yarn.container.mb 8192
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.llap.io.memory.size 1024
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.llap.io.threadpool.size 4
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.server2.tez.default.queues llap
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-site hive.tez.container.size 3072
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-env llap_heap_size 7168
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME hive-interactive-env slider_am_container_mb 1024
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME tez-interactive-site tez.am.resource.memory.mb 1024
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME tez-interactive-site tez.runtime.io.sort.mb 819
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME tez-interactive-site tez.runtime.unordered.output.buffer.size-mb 184
sleep 1

/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.default.minimum-user-limit-percent 100
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.maximum-am-resource-percent 0.3
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.maximum-applications 10000
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME  capacity-scheduler yarn.scheduler.capacity.node-locality-delay 40
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.accessible-node-labels "*"
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.acl_administer_queue "*"
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.capacity 100
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.acl_administer_jobs "*"
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.acl_submit_applications "*"
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.capacity 66.0
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.maximum-capacity 66.0
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.state RUNNING
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.default.user-limit-factor 1
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.acl_administer_queue hive
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.acl_submit_applications hive
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.capacity 34.0
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.maximum-am-resource-percent 1
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.maximum-capacity 34.0
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.minimum-user-limit-percent 100
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.ordering-policy fifo
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.priority 10
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.state RUNNING
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.llap.user-limit-factor 1
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.ordering-policy priority-utilization
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME capacity-scheduler yarn.scheduler.capacity.root.queues "default,llap"
sleep 1

/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME core-site hadoop.proxyuser.hive.hosts "$HOST1,$HOST2,$HOST3"
sleep 1

#Add symbolic links to Atlas Hooks
	ln -s /usr/hdp/current/atlas-client/hook/hive/atlas-plugin-classloader-0.8.0.2.6.1.0-129.jar /usr/hdp/current/hive-client/lib/atlas-plugin-classloader.jar

	ln -s /usr/hdp/current/atlas-client/hook/hive/hive-bridge-shim-0.8.0.2.6.1.0-129.jar /usr/hdp/current/hive-client/lib/hive-bridge-shim.jar

	sleep 2
    echo "*********************************Adding HIVE INTERACTIVE SERVER component..."
    # Add HIVE INTERACTIVE SERVER component to service
    curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER_INTERACTIVE

    sleep 2	
	echo "*********************************Adding HIVE INTERACTIVE SERVER role to Host..."
    # Add HIVE INTERACTIVE SERVER role to Ambari Host
    curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/HIVE_SERVER_INTERACTIVE
	
	sleep 2	
	echo "*********************************Install HIVE INTERACTIVE SERVER..."
    # Install HIVE INTERACTIVE SERVER
    curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"HostRoles": {"state": "INSTALLED"}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/HIVE_SERVER_INTERACTIVE
	
    sleep 2
    stopService YARN
    sleep 2
    startService YARN
	sleep 2
	
	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"HostRoles\": {\"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/HIVE_SERVER_INTERACTIVE | grep "id" | grep -Po '([0-9]+)')

	echo "*********************************Start HIVE INTERACTIVE SERVER..."
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
		TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
			LOOPESCAPE="true"
		fi
		echo "*********************************Start HIVE INTERACTIVE SERVER Task Status $TASKSTATUS"
        sleep 2
	done
}

configureAtlas () {
	#Enable Business Taxonomy
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME application-properties atlas.feature.taxonomy.enable true
	
	sleep 2
    stopService ATLAS
    sleep 2
    startServiceAndComplete ATLAS
	sleep 2
}

installNifiNars () {
	git clone https://github.com/vakshorton/NifiLivyIntegration
	git clone https://github.com/vakshorton/NifiDruidIntegration
	git clone https://github.com/vakshorton/NifiHistorianDean
	cd $ROOT_PATH/NifiDruidIntegration/
	mvn clean package
	cp $ROOT_PATH/NifiDruidIntegration/nifi-druid-bundle-nar/target/nifi-druid-bundle-nar-0.0.1-SNAPSHOT.nar /usr/hdf/current/nifi/lib/

	cd $ROOT_PATH/NifiLivyIntegration/
	mvn clean package
	cp $ROOT_PATH/NifiLivyIntegration/nifi-livy-bundle-nar/target/nifi-livy-bundle-nar-0.0.1-SNAPSHOT.nar /usr/hdf/current/nifi/lib/

	cd $ROOT_PATH/NifiHistorianDean/
	mvn clean package
	cp $ROOT_PATH/NifiHistorianDean/target/HistorianDeanReporter-0.0.1-SNAPSHOT.nar /usr/hdf/current/nifi/lib/
}

installHistorianService () {
	cp -Rvf CloudBreakArtifacts/recipes/HISTORIAN /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/
}

#echo "*********************************Download Configurations"
#git clone https://github.com/vakshorton/CloudBreakArtifacts
#cd CloudBreakArtifacts

export ROOT_PATH=~
echo "*********************************ROOT PATH IS: $ROOT_PATH"

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 1
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

export HADOOP_USER_NAME=hdfs
echo "*********************************HADOOP_USER_NAME set to HDFS"

kill -9 $(netstat -nlp|grep 9090|grep -Po '[0-9]+/[a-zA-Z]+'|grep -Po '[0-9]+')

if [ ! -d "/usr/jdk64" ]; then
	echo "*********************************Install and Enable Oracle JDK 8"
	wget http://public-repo-1.hortonworks.com/ARTIFACTS/jdk-8u77-linux-x64.tar.gz
	tar -vxzf jdk-8u77-linux-x64.tar.gz -C /usr
	mv /usr/jdk1.8.0_77 /usr/jdk64
	alternatives --install /usr/bin/java java /usr/jdk64/bin/java 3
	alternatives --install /usr/bin/javac javac /usr/jdk64/bin/javac 3
	alternatives --install /usr/bin/jar jar /usr/jdk64/bin/jar 3
	export JAVA_HOME=/usr/jdk64
	echo "export JAVA_HOME=/usr/jdk64" >> /etc/bashrc
	echo "export JAVA_HOME=/usr/jdk64" >> ~/.bash_profile
fi

echo "*********************************Waiting for cluster install to complete..."
waitForServiceToStart YARN

waitForServiceToStart HDFS

waitForServiceToStart HIVE

waitForServiceToStart ZOOKEEPER

sleep 10

export VERSION=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
export INTVERSION=$(echo $VERSION*10 | bc | grep -Po '([0-9][0-9])')
echo "*********************************HDP VERSION IS: $VERSION"

sed -r -i 's;\{\{mysql_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/registry-config/registry-common.json
sed -r -i 's;\{\{mysql_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-common.json
sed -r -i 's;\{\{registry_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-common.json
sed -r -i 's;\{\{superset_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/streamline-config/streamline-common.json
sed -r -i 's;\{\{mysql_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-common.json
sed -r -i 's;\{\{mysql_host\}\};'$AMBARI_HOST';' $ROOT_PATH/CloudBreakArtifacts/hdf-config/druid-config/druid-superset.json

export ZK_HOST=$AMBARI_HOST
export KAFKA_BROKER=$(getKafkaBroker)
export ATLAS_HOST=$(getAtlasHost)
export LIVY_HOST=$(getLivyHost)

export KAFKA_BROKER_IP=$(getent hosts $KAFKA_BROKER | awk '{ print $1 }')
/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME kafka-broker "listeners" "PLAINTEXT://$KAFKA_BROKER_IP:6667"

installHistorianService
sleep 2
instalHDFManagementPack 
sleep 2
#configureAmbariRepos
#sleep 2
installUtils
sleep 2
installMySQL
sleep 2
setupHDFDataStores
sleep 2
installDruidService
sleep 2
startServiceIfReady DRUID
sleep 2
export DRUID_BROKER=$(getDruidBroker)
sleep 2
installSchemaRegistryService
sleep 2
startServiceIfReady REGISTRY
sleep 5
installNifiService
sleep 5
installNifiNars
sleep 2
startServiceIfReady NIFI
sleep 2
configureHive
sleep 2
configureAtlas

exit 0

#export MYSQL_TEMP_PASSWORD=$(grep 'A temporary password' /var/log/mysqld.log |grep -Po ': .+'|grep -Po '[^: ].+')
#mysqladmin -u root --password=$MYSQL_TEMP_PASSWORD password "Password!1"
#export MYSQL_PASSWORD=Password!1

#mysql -u root --password=$MYSQL_PASSWORD --execute="uninstall plugin validate_password"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE DATABASE registry"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE DATABASE streamline"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE DATABASE druid DEFAULT CHARACTER SET utf8"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE DATABASE superset DEFAULT CHARACTER SET utf8"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE USER 'registry'@'%' IDENTIFIED BY 'registry'"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE USER 'streamline'@'%' IDENTIFIED BY 'streamline'"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE USER 'druid'@'%' IDENTIFIED BY 'druid'"
#mysql -u root --password=$MYSQL_PASSWORD --execute="CREATE USER 'superset'@'%' IDENTIFIED BY 'superset'"
#mysql -u root --password=$MYSQL_PASSWORD --execute="GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION"
#mysql -u root --password=$MYSQL_PASSWORD --execute="GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION"
#mysql -u root --password=$MYSQL_PASSWORD --execute="GRANT ALL PRIVILEGES ON druid.* TO 'druid'@'%' WITH GRANT OPTION"
#mysql -u root --password=$MYSQL_PASSWORD --execute="GRANT ALL PRIVILEGES ON superset.* TO 'superset'@'%' WITH GRANT OPTION"
#mysql -u root --password=$MYSQL_PASSWORD --execute="FLUSH PRIVILEGES"
#mysql -u root --password=$MYSQL_PASSWORD --execute="COMMIT"