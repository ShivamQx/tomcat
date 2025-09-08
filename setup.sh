#!/bin/bash
set -e

# 1. Update package lists and upgrade
sudo apt update -y && sudo apt upgrade -y

# 2. Install Java JDK (OpenJDK 21)
echo "Installing Java JDK..."
sudo apt install -y openjdk-21-jdk

# 3. Verify Java installation
java -version

# 4. Define variables for Tomcat installation
TOMCAT_VERSION=10.1.44
TOMCAT_DIR=/opt/tomcat

# 5. Download and install Tomcat
echo "Downloading Apache Tomcat $TOMCAT_VERSION..."
wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -P /tmp

echo "Extracting Tomcat..."
sudo mkdir -p $TOMCAT_DIR
sudo tar xzvf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_DIR --strip-components=1

# 6. Set executable permissions for scripts
sudo chmod +x $TOMCAT_DIR/bin/*.sh

# 7. Configure environment variables
echo "Configuring environment variables..."
cat << EOL | sudo tee /etc/profile.d/tomcat.sh
export CATALINA_HOME=$TOMCAT_DIR
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=\$PATH:\$CATALINA_HOME/bin:\$JAVA_HOME/bin
EOL

# 8. Reload environment variables
source /etc/profile.d/tomcat.sh

# 9. Create a demo Servlet project
echo "Creating demo Servlet project..."
PROJECT_DIR=~/DemoServlet
mkdir -p $PROJECT_DIR/{src,WEB-INF/classes}
cd $PROJECT_DIR

# 10. Servlet source code
cat << EOL > src/HelloServlet.java
import java.io.*;
import jakarta.servlet.*;
import jakarta.servlet.http.*;

public class HelloServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException, ServletException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("<h1>Hello, Servlet World!</h1>");
    }
}
EOL

# 11. web.xml configuration
mkdir -p WEB-INF
cat << EOL > WEB-INF/web.xml
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                             https://jakarta.ee/xml/ns/jakartaee/web-app_5_0.xsd"
         version="5.0">
    <servlet>
        <servlet-name>HelloServlet</servlet-name>
        <servlet-class>HelloServlet</servlet-class>
    </servlet>
    <servlet-mapping>
        <servlet-name>HelloServlet</servlet-name>
        <url-pattern>/hello</url-pattern>
    </servlet-mapping>
</web-app>
EOL

# 12. Compile the Servlet
echo "Compiling HelloServlet..."
javac -cp $CATALINA_HOME/lib/jakarta.servlet-api.jar -d WEB-INF/classes src/HelloServlet.java

# 13. Package the application into a WAR file
echo "Packaging the project into DemoApp.war..."
cd WEB-INF/classes
jar cvf ~/DemoServlet/DemoApp.war ./*
mv ~/DemoServlet/DemoApp.war $TOMCAT_HOME
cd ~/DemoServlet

# 14. Deploy the WAR
echo "Deploying DemoApp.war to Tomcat..."
sudo cp DemoApp.war $CATALINA_HOME/webapps/

# 15. Start Tomcat
echo "Starting Tomcat..."
$CATALINA_HOME/bin/startup.sh

echo "Done! Visit: http://localhost:8080/DemoApp/hello to see your servlet."
