pipeline {
    agent any
    environment{
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_REPO_NAME = "clarusway-repo/phonebook-app-qa"
        APP_NAME = "phonebook"
        DOMAIN_NAME = "mehmetafsar.net"
        FQDN = "clarusway.mehmetafsar.net"
        AWS_STACK_NAME = "Mehmet-Phonebook-App-qa"
        CFN_TEMPLATE="phonebook-docker-swarm-cfn-template.yml"
        CFN_KEYPAIR="thedoctor"
        HOME_FOLDER = "/home/ec2-user"
        GIT_FOLDER = sh(script:'echo ${GIT_URL} | sed "s/.*\\///;s/.git$//"', returnStdout:true).trim()

    }

    stages {
        stage('creating ECR Repository'){
            agent any
            steps{
                echo 'creating ECR Repository'
                sh '''
                    RepoArn=$(aws ecr describe-repositories --region ${AWS_REGION} | grep ${APP_REPO_NAME} |cut -d '"' -f 4| head -n 1 )  || true
                    if [ "$RepoArn" == '' ]
                    then
                        aws ecr create-repository \
                          --repository-name ${APP_REPO_NAME} \
                          --image-scanning-configuration scanOnPush=false \
                          --image-tag-mutability MUTABLE \
                          --region ${AWS_REGION}
                        
                    fi
                '''
            }
        }
        stage('get-keypair'){
            agent any
            steps{
                sh '''
                    if [ -f "${CFN_KEYPAIR}.pem" ]
                    then 
                        echo "file exists..."
                    else
                        aws ec2 create-key-pair \
                          --region ${AWS_REGION} \
                          --key-name ${CFN_KEYPAIR} \
                          --query KeyMaterial \
                          --output text > ${CFN_KEYPAIR}.pem
                        chmod 400 ${CFN_KEYPAIR}.pem
                        
                        ssh-keygen -y -f ${CFN_KEYPAIR}.pem >> ${CFN_KEYPAIR}.pub
                        cp -f ${CFN_KEYPAIR}.pem ${JENKINS_HOME}/.ssh
                        chown jenkins:jenkins ${JENKINS_HOME}/.ssh/${CFN_KEYPAIR}.pem
                    fi
                '''                
            }
        }
        stage('building Docker Image') {
            steps {
                echo 'building Docker Image'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:latest" .'
                sh 'docker image ls'
            }
        }
        stage('pushing Docker image to ECR Repository'){   
            steps {
                echo 'pushing Docker image to ECR Repository'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:latest"'

            }
        }

        stage('pushing .env to Jenkins to Git Repository') {
            steps {
                script {
                  catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    withCredentials([usernamePassword(credentialsId: 'git-credentials', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        def encodedPassword = URLEncoder.encode("$GIT_PASSWORD",'UTF-8')
                        writeFile file: '.env', text: "ECR_REGISTRY=${ECR_REGISTRY}\nAPP_REPO_NAME=${APP_REPO_NAME}:latest"
                        echo 'pushing .env to Jenkins to Git Repository'
                        sh "cd ${WORKSPACE}"
                        sh "git config user.email admin@example.com"
                        sh "git config user.name example"
                        sh "git add ."
                        sh "git commit -m 'Triggered Build: ${env.BUILD_NUMBER}'"
                        sh "git push https://${GIT_USERNAME}:${encodedPassword}@github.com/${GIT_USERNAME}/${GIT_FOLDER}.git HEAD:master"
                }
              }
            }
          }
        }

        stage('creating infrastructure for the Application') {
            steps {
                echo 'creating infrastructure for the Application'
                sh '''
                    MasterIp=$(aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=docker-grand-master Name=tag-value,Values=${AWS_STACK_NAME} --query Reservations[*].Instances[*].[PublicIpAddress] --output text)  || true
                    if [ "$MasterIp" == '' ]
                    then
                        aws cloudformation create-stack --stack-name ${AWS_STACK_NAME} \
                          --capabilities CAPABILITY_IAM \
                          --template-body file://${CFN_TEMPLATE} \
                          --region ${AWS_REGION} --parameters ParameterKey=KeyPairName,ParameterValue=${CFN_KEYPAIR} 
                          
                        
                    fi
                '''
            script {
                while(true) {
                        
                        echo "Docker Grand Master is not UP and running yet. Will try to reach again after 10 seconds..."
                        sleep(10)

                        ip = sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=docker-grand-master Name=tag-value,Values=${AWS_STACK_NAME} --query Reservations[*].Instances[*].[PublicIpAddress] --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()

                        if (ip.length() >= 7) {
                            echo "Docker Grand Master Public Ip Address Found: $ip"
                            env.MASTER_INSTANCE_PUBLIC_IP = "$ip"
                            break
                        }
                    }
                }
            }
        }
        stage('Test the infrastructure') {
            steps {
                echo "Testing if the Docker Swarm is ready or not, by checking Viz App on Grand Master with Public Ip Address: ${MASTER_INSTANCE_PUBLIC_IP}:8080"
            script {
                while(true) {
                    try {
                      sh "curl -s --connect-timeout 60 ${MASTER_INSTANCE_PUBLIC_IP}:8080"
                      echo "Successfully connected to Viz App."
                      break
                    }
                    catch(Exception) {
                      echo 'Could not connect Viz App'
                      sleep(5)   
                    }
                }
            }
        }
    }

        stage('dns-record-control'){
            agent any
            steps{
                withAWS(credentials: 'mycredentials', region: 'us-east-1') {
                    script {
                        env.ZONE_ID = sh(script:"aws route53 list-hosted-zones-by-name --dns-name $DOMAIN_NAME --query HostedZones[].Id --output text | cut -d/ -f3", returnStdout:true).trim()
                        env.ELB_DNS = sh(script:"aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --query \"ResourceRecordSets[?Name == '\$FQDN.']\" --output text | tail -n 1 | cut -f2", returnStdout:true).trim() 
                    }
                    sh "sed -i 's|{{DNS}}|$ELB_DNS|g' deleterecord.json"
                    sh "sed -i 's|{{FQDN}}|$FQDN|g' deleterecord.json"
                    sh '''
                        RecordSet=$(aws route53 list-resource-record-sets   --hosted-zone-id $ZONE_ID   --query ResourceRecordSets[] | grep -i $FQDN) || true
                        if [ "$RecordSet" != '' ]
                        then
                            aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://deleterecord.json
                        
                        fi
                    '''
                    
                }                  
            }
        }

        stage('dns-record-kube-master'){
            agent any
            steps{
                withAWS(credentials: 'mycredentials', region: 'us-east-1') {
                    script {
                        env.ELB_DNS = sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=docker-grand-master Name=tag-value,Values=${AWS_STACK_NAME} --query Reservations[*].Instances[*].[PublicIpAddress] --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()
                        env.ZONE_ID = sh(script:"aws route53 list-hosted-zones-by-name --dns-name $DOMAIN_NAME --query HostedZones[].Id --output text | cut -d/ -f3", returnStdout:true).trim()   
                    }
                    sh "sed -i 's|{{DNS}}|$ELB_DNS|g' dnsrecord.json"
                    sh "sed -i 's|{{FQDN}}|$FQDN|g' dnsrecord.json"
                    sh "aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://dnsrecord.json"
                    
                }                  
            }
        }

        stage('Deploying the Application'){
            environment {
                MASTER_INSTANCE_ID=sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=docker-grand-master Name=tag-value,Values=${AWS_STACK_NAME} --query Reservations[*].Instances[*].[InstanceId] --output text', returnStdout:true).trim()
            }
            steps {
                sh "sed -i 's/{SERVERIP}/${MASTER_INSTANCE_PUBLIC_IP}/g' ssl-script.sh"
                sh "sed -i 's/{FullDomainName}/${FQDN}/g' ssl-script.sh"
                sh "sed -i 's/{GIT_FOLDER}/${GIT_FOLDER}/g' git.sh"
                sh "sed -i 's|{GIT_URL}|${GIT_URL}|g' git.sh"
                echo "Cloning and Deploying App on Swarm using Grand Master with Instance Id: $MASTER_INSTANCE_ID"
                sh '''scp -o StrictHostKeyChecking=no \
                        -o UserKnownHostsFile=/dev/null \
                        -i ${JENKINS_HOME}/.ssh/${CFN_KEYPAIR}.pem git.sh ec2-user@\"${MASTER_INSTANCE_PUBLIC_IP}":/home/ec2-user/
                    '''
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} bash ${HOME_FOLDER}/git.sh"
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} chmod 777 ${HOME_FOLDER}/${GIT_FOLDER}/deploy.sh "
                sleep(10)
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} bash ${HOME_FOLDER}/${GIT_FOLDER}/deploy.sh"
                sh '''scp -o StrictHostKeyChecking=no \
                        -o UserKnownHostsFile=/dev/null \
                        -i ${JENKINS_HOME}/.ssh/${CFN_KEYPAIR}.pem ssl-script.sh ec2-user@\"${MASTER_INSTANCE_PUBLIC_IP}":/home/ec2-user/${GIT_FOLDER}
                    '''
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} sudo bash ${HOME_FOLDER}/${GIT_FOLDER}/ssl-script.sh"
            }
        }
    }
    post {
        always {
            echo 'Deleting all local images'
            sh 'docker image prune -af'
        }
        success {
            echo 'You are the man/woman...'
            echo 'You can visit https://${FQDN}:8080 and  https://${FQDN}'
        }
    }
}
