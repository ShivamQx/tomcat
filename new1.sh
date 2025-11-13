#!/bin/bash
set -e

# ==============================
# Config
# ==============================
APP_NAME=${1:-DemoApp}
GROUP_ID=com.example
PACKAGE_NAME=com.example
ARTIFACT_ID=$APP_NAME
PROJECT_DIR=$HOME/$APP_NAME

TOMCAT_VERSION=10.1.49
TOMCAT_DIR=/opt/tomcat

# ==============================
# Install dependencies
# ==============================
echo "===== Updating system ====="
sudo apt update -y && sudo apt upgrade -y

echo "===== Installing Java 21 ====="
sudo apt install -y openjdk-21-jdk

echo "===== Installing Maven ====="
sudo apt install -y maven wget unzip

echo "===== Checking Java and Maven ====="
java -version
mvn -version

# ==============================
# Install Tomcat
# ==============================
echo "===== Installing Apache Tomcat ====="
if [ ! -d "$TOMCAT_DIR" ]; then
    wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -P /tmp
    sudo mkdir -p $TOMCAT_DIR
    sudo tar xzvf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR --strip-components=1
    sudo chmod +x $TOMCAT_DIR/bin/*.sh

    echo "export CATALINA_HOME=$TOMCAT_DIR" | sudo tee /etc/profile.d/tomcat.sh
    echo "export PATH=\$PATH:\$CATALINA_HOME/bin" | sudo tee -a /etc/profile.d/tomcat.sh
    source /etc/profile.d/tomcat.sh
else
    echo "Tomcat already exists at $TOMCAT_DIR"
fi

# ==============================
# Create Maven Web Project (Safe Method)
# ==============================
echo "===== Creating Maven Web Project ====="

TMP_DIR=/tmp/${APP_NAME}_gen
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

mvn archetype:generate \
    -DgroupId=$GROUP_ID \
    -DartifactId=$ARTIFACT_ID \
    -DarchetypeArtifactId=maven-archetype-webapp \
    -DinteractiveMode=false

# Move project safely
if [ ! -d "$PROJECT_DIR" ]; then
    mv $ARTIFACT_ID $PROJECT_DIR
else
    echo "Project already exists → Skipping move"
fi

cd $PROJECT_DIR

# ==============================
# Create pom.xml for Java 21
# ==============================
cat << EOL > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <groupId>$GROUP_ID</groupId>
    <artifactId>$ARTIFACT_ID</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>war</packaging>

    <properties>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>jakarta.servlet</groupId>
            <artifactId>jakarta.servlet-api</artifactId>
            <version>6.0.0</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>

    <build>
        <finalName>$APP_NAME</finalName>

        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>21</source>
                    <target>21</target>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.3.2</version>
            </plugin>
        </plugins>
    </build>

</project>
EOL

# ==============================
# Add HelloServlet
# ==============================
SRC_DIR=src/main/java/${PACKAGE_NAME//.//}
mkdir -p $SRC_DIR

cat << EOL > $SRC_DIR/HelloServlet.java
package $PACKAGE_NAME;

import java.io.IOException;
import java.io.PrintWriter;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class HelloServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException, ServletException {

        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("<h1>Hello from $APP_NAME using Java 21!</h1>");
    }
}
EOL

# ==============================
# Add web.xml
# ==============================
mkdir -p src/main/webapp/WEB-INF

cat << EOL > src/main/webapp/WEB-INF/web.xml
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                             https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">

    <servlet>
        <servlet-name>HelloServlet</servlet-name>
        <servlet-class>$PACKAGE_NAME.HelloServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>HelloServlet</servlet-name>
        <url-pattern>/hello</url-pattern>
    </servlet-mapping>

</web-app>
EOL

# ==============================
# Build WAR
# ==============================
echo "===== Building WAR ====="
mvn clean package -DskipTests

# ==============================
# Deploy WAR
# ==============================
echo "===== Deploying to Tomcat ====="
sudo rm -rf $TOMCAT_DIR/webapps/$APP_NAME
sudo cp target/$APP_NAME.war $TOMCAT_DIR/webapps/

echo "===== Restarting Tomcat ====="
$TOMCAT_DIR/bin/shutdown.sh || true
sleep 2
$TOMCAT_DIR/bin/startup.sh

echo "==========================================="
echo " Deployment Complete!"
echo " Visit:"
echo " → http://localhost:8080/$APP_NAME/hello"
echo "==========================================="
