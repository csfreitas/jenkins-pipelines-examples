
//java project artifactID
def GUID = "${APP_NAME}"

pipeline {
  agent {
    node {
      label 'maven'
    }
  }
  environment { 
    // Define global variables
    // NOTE: Somehow an inline pod template in a declarative pipeline
    //       needs the "scl_enable" before calling maven.
    mvnCmd = "source /usr/local/bin/scl_enable && mvn"

    // Images and Projects
    imageName   = "${APP_NAME}"
    devProject  = "${OPENSHIFT_PROJECT}"
    prodProject = "${OPENSHIFT_PROJECT_PROD}"

    // Tags
    devTag      = "0.0-0"
    prodTag     = "0.0"
    
    // Blue-Green Settings
    destApp     = "${APP_NAME}-green"
    activeApp   = ""
  }
  stages {
    // Checkout Source Code.
    stage('Checkout Source') {
      steps {
        checkout scm

        dir('openshift-tasks') {
          script {
            def pom = readMavenPom file: 'pom.xml'
            def version = pom.version
            
            // Set the tag for the development image: version + build number
            devTag  = "${version}-" + currentBuild.number
            // Set the tag for the production image: version
            prodTag = "${version}"

            // Patch Source artifactId to include GUID
            sh "sed -i 's/GUID/${GUID}/g' ./pom.xml"
          }
        }
      }
    }

    // Build the Tasks Application in the directory 'openshift-tasks'
    stage('Build war') {
      steps {
        dir('openshift-tasks') {
          echo "Building version ${devTag}"
          script {

            sh "${mvnCmd} clean package -DskipTests=true"

          }
        }
      }
    }

    // Using Maven run the unit tests
    stage('Unit Tests') {
      steps {
        dir('openshift-tasks') {
          echo "Running Unit Tests"
          sh "${mvnCmd} test"
        }
      }
    }
    // Using Maven call SonarQube for Code Analysis
    stage('Code Analysis') {
      steps {
        dir('openshift-tasks') {
          script {
            echo "Running Code Analysis"

            //      Your project name should be "${GUID}-${JOB_BASE_NAME}-${devTag}"
            //      Your project version should be ${devTag}

            //sh "${mvnCmd} sonar:sonar \
            //      -Dsonar.host.url=http://homework-sonarqube.apps.shared.na.openshift.opentlc.com/ \
            //        -Dsonar.projectName=${GUID}-${JOB_BASE_NAME}-${devTag} \
            //        -Dsonar.projectVersion=${devTag}"
            sleep(2) 
          }
        }
      }
    }
    // Publish the built war file to Nexus
    stage('Publish to Nexus') {
      steps {
        dir('openshift-tasks') {
          echo "Publish to Nexus"

          //sh "${mvnCmd} deploy \
          //    -DskipTests=true \
          //    -DaltDeploymentRepository=nexus::default::http://homework-nexus.gpte-hw-cicd.svc.cluster.local:8081/repository/releases"
          sleep(2) 
        }
      }
    }
    // Build the OpenShift Image in OpenShift and tag it.
    stage('Build and Tag OpenShift Image') {
      steps {
        dir('openshift-tasks') {
          echo "Building OpenShift container image ${imageName}:${devTag} in project ${devProject}."

          script {
            // TBD: Build Image (binary build), tag Image
            //      Make sure the image name is correct in the tag!

            openshift.withCluster() {
              openshift.withProject("${devProject}") {
                openshift.selector("bc", "tasks").startBuild("--from-file=./target/openshift-tasks.war", "--wait=true")
                openshift.tag("${imageName}:latest", "${imageName}:${devTag}")
              }
            }
          }
        }
      }
    }
    // Deploy the built image to the Development Environment.
    stage('Deploy to Dev') {
      steps {
        dir('openshift-tasks') {
          echo "Deploying container image to Development Project"
          script {
            openshift.withCluster() {        
              openshift.withProject("${devProject}") {
                //1 Update the image on the dev deployment config
                openshift.set("image", "dc/${APP_NAME}", "${APP_NAME}=image-registry.openshift-image-registry.svc:5000/${devProject}/${imageName}:${devTag}")

                //2 Update the config maps with the potentially changed properties files
                openshift.selector('configmap', '{APP_NAME}-config').delete()
                def configmap = openshift.create('configmap', '${APP_NAME}-config', '--from-file=./configuration/application-users.properties', '--from-file=./configuration/application-roles.properties')

                //3 Reeploy the dev deployment
                openshift.selector("dc", "${APP_NAME}").rollout().latest();

                //4 Wait until the deployment is running
                def dc = openshift.selector("dc", "${APP_NAME}").object()
                def dc_version = dc.status.latestVersion
                def rc = openshift.selector("rc", "${APP_NAME}-${dc_version}").object()

                echo "Waiting for ReplicationController ${APP_NAME}-${dc_version} to be ready"
                while (rc.spec.replicas != rc.status.readyReplicas) {
                  sleep 5
                  rc = openshift.selector("rc", "${APP_NAME}-${dc_version}").object()
                }
              }
            }
          }
        }
      }
    }

    // Copy Image to Nexus Container Registry
    /*stage('Copy Image to Nexus Container Registry') {
      steps {
        echo "Copy image to Nexus Container Registry"
        script {

          //Copy image to Nexus container registry

          sh "skopeo copy --src-tls-verify=false \
                          --dest-tls-verify=false \
                          --src-creds openshift:\$(oc whoami -t) \
                          --dest-creds admin:redhat docker://image-registry.openshift-image-registry.svc:5000/${devProject}/${imageName}:${devTag} docker://homework-nexus-registry.gpte-hw-cicd.svc.cluster.local:5000/${imageName}:${devTag}"

          // Tag the built image with the production tag.
          openshift.withCluster() {
            openshift.withProject("${prodProject}") {
              openshift.tag("${devProject}/${imageName}:${devTag}", "${devProject}/${imageName}:${prodTag}")
            }
          }

        }
      }
    }*/

    // Blue/Green Deployment into Production
    // -------------------------------------
    stage('Blue/Green Production Deployment') {
      steps {
        script {

          //      Set Image, Set VERSION
          //      (Re-)create ConfigMap
          //      Deploy into the other application
          //      Make sure the application is running and ready before proceeding

          openshift.withCluster() {
            openshift.withProject("${prodProject}") {
              activeApp = openshift.selector("route", "${APP_NAME}").object().spec.to.name
              if (activeApp == "${APP_NAME}-green") {
                destApp = "${APP_NAME}-blue"
              }
              echo "Active Application:      " + activeApp
              echo "Destination Application: " + destApp

              // Update the Image on the Production Deployment Config
              def dc = openshift.selector("dc/${destApp}").object()
              dc.spec.template.spec.containers[0].image="image-registry.openshift-image-registry.svc:5000/${devProject}/${APP_NAME}:${prodTag}"

              // Deploy of application
              openshift.apply(dc)

              // Update Config Map in change config files changed in the source
              openshift.selector('configmap', "${destApp}-config").delete()
              def configmap = openshift.create("configmap", "${destApp}-config", "--from-file=./openshift-tasks/configuration/application-users.properties", "--from-file=./openshift-tasks/configuration/application-roles.properties")

              // Deploy the inactive application.
              openshift.selector("dc", "${destApp}").rollout().latest();

              // Wait for application to be deployed
              def dc_prod = openshift.selector("dc", "${destApp}").object()
              def dc_version = dc_prod.status.latestVersion
              def rc_prod = openshift.selector("rc", "${destApp}-${dc_version}").object()
              echo "Waiting for ${destApp} to be ready"
              while (rc_prod.spec.replicas != rc_prod.status.readyReplicas) {
                sleep 5
                rc_prod = openshift.selector("rc", "${destApp}-${dc_version}").object()
              }
            }
          } 
        }
      }
    }

    stage('Switch over to new Version') {
      steps{
        echo "Switching Production application to ${destApp}."
        script {
          //      Hint: sleep 5 seconds after the switch
          //            for the route to be fully switched over

          openshift.withCluster() {
            openshift.withProject("${prodProject}") {
              def route = openshift.selector("route/${APP_NAME}").object()
              route.spec.to.name="${destApp}"
              openshift.apply(route)
              sleep 5
            }
          }

        }
      }
    }
  }
}
