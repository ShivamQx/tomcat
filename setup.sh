#!/bin/bash
set -e

# 1. Update package lists
echo "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

# 2. Install Java JDK if not already installed
if command -v java &>/dev/null; then
    echo "Java already installed: $(java -version 2>&1 | head -n 1)"
else
    echo "Installing default OpenJDK..."
    sudo apt install -y default-jdk
fi

# 3. Verify Java installation
java -version

# 4. Define variables for Tomcat installation
TOMCAT_VERSION=10.1.44
TOMCAT_DIR=/opt/tomcat
TOMCAT_TAR=/tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz

# 5. Download and install Tomcat if not already installed
if [ -d "$TOMCAT_DIR" ]; then
    echo "Tomcat already exists at $TOMCAT_DIR, skipping installation."
else
    echo "Downloading Apache Tomcat $TOMCAT_VERSION..."
    wget -q https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -O $TOMCAT_TAR
    
    echo "Extracting Tomcat..."
    sudo mkdir -p $TOMCAT_DIR
    sudo tar xzvf $TOMCAT_TAR -C $TOMCAT_DIR --strip-components=1
    sudo chmod +x $TOMCAT_DIR/bin/*.sh
fi

# 6. Configure environment variables safely
TOMCAT_ENV_FILE=/etc/profile.d/tomcat.sh
if [ ! -f "$TOMCAT_ENV_FILE" ]; then
    echo "Configuring environment variables..."
    cat << EOL | sudo tee $TOMCAT_ENV_FILE
export CATALINA_HOME=$TOMCAT_DIR
export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(which java))))
export PATH=\$PATH:\$CATALINA_HOME/bin:\$JAVA_HOME/bin
EOL
fi

# Reload environment variables
source $TOMCAT_ENV_FILE

# 7. Create a demo Servlet project
PROJECT_DIR=~/DemoServlet
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating demo Servlet project..."
    mkdir -p $PROJECT_DIR/{src,WEB-INF/classes}
    
    # Servlet source code
    cat << 'EOL' > $PROJECT_DIR/src/HelloServlet.java
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

    # web.xml configuration
    mkdir -p $PROJECT_DIR/WEB-INF
    cat << 'EOL' > $PROJECT_DIR/WEB-INF/web.xml
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
fi

# 8. Compile the Servlet if source is newer than class
SRC_FILE=$PROJECT_DIR/src/HelloServlet.java
CLASS_FILE=$PROJECT_DIR/WEB-INF/classes/HelloServlet.class
if [ ! -f "$CLASS_FILE" ] || [ "$SRC_FILE" -nt "$CLASS_FILE" ]; then
    echo "Compiling HelloServlet..."
    javac -cp "$CATALINA_HOME/lib/*" -d $PROJECT_DIR/WEB-INF/classes $SRC_FILE
fi

# 9. Package the application into a WAR file
WAR_FILE=$PROJECT_DIR/DemoApp.war
if [ ! -f "$WAR_FILE" ] || [ "$CLASS_FILE" -nt "$WAR_FILE" ] || [ "$PROJECT_DIR/WEB-INF/web.xml" -nt "$WAR_FILE" ]; then
    echo "Packaging the project into DemoApp.war..."
    cd $PROJECT_DIR
    jar cvf DemoApp.war WEB-INF
fi

# 10. Deploy the WAR (always redeploy if updated)
DEPLOYED_WAR=$CATALINA_HOME/webapps/DemoApp.war
if [ ! -f "$DEPLOYED_WAR" ] || [ "$WAR_FILE" -nt "$DEPLOYED_WAR" ]; then
    echo "Redeploying DemoApp.war to Tomcat..."
    sudo rm -rf $CATALINA_HOME/webapps/DemoApp   # remove old exploded folder
    sudo cp -f $WAR_FILE $CATALINA_HOME/webapps/
    
    echo "Restarting Tomcat..."
    $CATALINA_HOME/bin/shutdown.sh || true
    sleep 3
    $CATALINA_HOME/bin/startup.sh
else
    echo "No changes detected in WAR, keeping current deployment."
fi

echo "✅ Setup complete! Visit: http://localhost:8080/DemoApp/hello"
