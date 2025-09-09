#!/bin/bash
set -e

# ==============================
# Config
# ==============================
TOMCAT_VERSION=10.1.44
TOMCAT_DIR=/opt/tomcat
PROJECT_DIR=~/DemoApp

# ==============================
# Install dependencies
# ==============================
echo "===== Updating system ====="
sudo apt update -y && sudo apt upgrade -y

echo "===== Installing Java (default JDK) ====="
sudo apt install -y default-jdk

echo "===== Installing Maven ====="
sudo apt install -y maven

echo "===== Checking Java and Maven ====="
java -version
mvn -v

# ==============================
# Install Tomcat
# ==============================
echo "===== Installing Apache Tomcat if not exists ====="
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
# Create Maven Web Project
# ==============================
echo "===== Creating Maven Web Project ====="
if [ ! -d "$PROJECT_DIR" ]; then
    mvn archetype:generate \
        -DgroupId=com.example \
        -DartifactId=DemoApp \
        -DarchetypeArtifactId=maven-archetype-webapp \
        -DinteractiveMode=false
    mv DemoApp $PROJECT_DIR
else
    echo "Maven project already exists at $PROJECT_DIR"
fi

cd $PROJECT_DIR

# ==============================
# Ensure pom.xml is correct
# ==============================
cat << 'EOL' > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>DemoApp</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>war</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>jakarta.servlet</groupId>
            <artifactId>jakarta.servlet-api</artifactId>
            <version>6.0.0</version>
            <scope>provided</scope>
        </dependency>

        <!-- MySQL JDBC Connector -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>9.4.0</version>
        </dependency>
    </dependencies>

    <build>
        <finalName>DemoApp</finalName>
        <plugins>
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
# Ensure HelloServlet.java exists
# ==============================
mkdir -p src/main/java/com/example
cat << 'EOL' > src/main/java/com/example/HelloServlet.java
package com.example;

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
        out.println("<h1>Hello, Maven + Tomcat World!</h1>");
    }
}
EOL

# ==============================
# Create DBServlet.java
# ==============================
cat << 'EOL' > src/main/java/com/example/DBServlet.java
package com.example;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.*;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class DBServlet extends HttpServlet {
    private static final String JDBC_URL = "jdbc:mysql://localhost:3306/jdbc";
    private static final String JDBC_USER = "root";
    private static final String JDBC_PASS = "";

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException, ServletException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();

        try {
            // Explicitly load MySQL Driver
            Class.forName("com.mysql.cj.jdbc.Driver");

            Connection conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASS);
            out.println("<h1>Connected to Database!</h1>");

            // Insert sample data
            String insert = "INSERT INTO users(name, email) VALUES (?, ?)";
            try (PreparedStatement ps = conn.prepareStatement(insert)) {
                ps.setString(1, "Alice");
                ps.setString(2, "alice@example.com");
                ps.executeUpdate();
            }

            // Fetch users
            out.println("<h2>Users:</h2><ul>");
            String query = "SELECT * FROM users";
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery(query)) {
                while (rs.next()) {
                    out.println("<li>" + rs.getInt("id") + " - " +
                                rs.getString("name") + " - " +
                                rs.getString("email") + "</li>");
                }
            }
            out.println("</ul>");
        } catch (Exception e) {
            out.println("<p style='color:red;'>Error: " + e.getMessage() + "</p>");
        }
    }
}
EOL

# ==============================
# Ensure web.xml exists
# ==============================
mkdir -p src/main/webapp/WEB-INF
cat << 'EOL' > src/main/webapp/WEB-INF/web.xml
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                             https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">

    <servlet>
        <servlet-name>HelloServlet</servlet-name>
        <servlet-class>com.example.HelloServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>HelloServlet</servlet-name>
        <url-pattern>/hello</url-pattern>
    </servlet-mapping>

    <servlet>
        <servlet-name>DBServlet</servlet-name>
        <servlet-class>com.example.DBServlet</servlet-class>
    </servlet>

    <servlet-mapping>
        <servlet-name>DBServlet</servlet-name>
        <url-pattern>/db</url-pattern>
    </servlet-mapping>
</web-app>
EOL

# ==============================
# Build WAR
# ==============================
echo "===== Building WAR with Maven ====="
mvn clean package -DskipTests

WAR_FILE=target/DemoApp.war

# ==============================
# Copy JDBC driver to Tomcat lib
# ==============================
echo "===== Copying JDBC driver to Tomcat lib ====="
MYSQL_JAR=$(find ~/.m2/repository/com/mysql/mysql-connector-j/9.4.0 -name "mysql-connector-j-9.4.0.jar" | head -n 1)
if [ -f "$MYSQL_JAR" ]; then
    sudo cp "$MYSQL_JAR" $TOMCAT_DIR/lib/
    echo "MySQL Connector copied to Tomcat lib."
else
    echo "ERROR: MySQL connector JAR not found in Maven repo."
fi

# ==============================
# Deploy to Tomcat
# ==============================
echo "===== Deploying WAR to Tomcat ====="
sudo rm -rf $TOMCAT_DIR/webapps/DemoApp
sudo cp -f $WAR_FILE $TOMCAT_DIR/webapps/

echo "===== Restarting Tomcat ====="
$TOMCAT_DIR/bin/shutdown.sh || true
sleep 3
$TOMCAT_DIR/bin/startup.sh

echo "===== Deployment Complete ====="
echo "Visit: http://localhost:8080/DemoApp/hello"
echo "Visit: http://localhost:8080/DemoApp/db"
