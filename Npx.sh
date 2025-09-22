#!/bin/bash

# ==============================================
# Chat Application Setup (Java + React)
# ==============================================

# Stop script on error
set -e

# -------- CONFIG --------
BACKEND_DIR="chat-backend"
FRONTEND_DIR="chat-frontend"
JAVA_VERSION="17"

echo "🚀 Setting up Chat Application with Java (Spring Boot) + React..."

# -------- Install Dependencies --------
echo "📦 Checking dependencies..."

# Java & Maven
if ! command -v java &> /dev/null; then
  echo "❌ Java not found. Please install OpenJDK $JAVA_VERSION."
  exit 1
fi

if ! command -v mvn &> /dev/null; then
  echo "❌ Maven not found. Installing Maven..."
  sudo apt-get update && sudo apt-get install -y maven
fi

# Node & npm
if ! command -v npm &> /dev/null; then
  echo "❌ Node.js not found. Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# -------- Create Backend --------
echo "📡 Creating Spring Boot Backend..."

mkdir -p $BACKEND_DIR
cd $BACKEND_DIR

# Init Maven project if not exists
if [ ! -f "pom.xml" ]; then
  mvn archetype:generate \
    -DgroupId=com.chatapp \
    -DartifactId=$BACKEND_DIR \
    -DarchetypeArtifactId=maven-archetype-quickstart \
    -DinteractiveMode=false
  cd $BACKEND_DIR
fi

# Overwrite pom.xml with dependencies
cat > pom.xml << 'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.chatapp</groupId>
    <artifactId>chat-backend</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-websocket</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create src files
mkdir -p src/main/java/com/chatapp/{config,controller,model}

# Application entry
cat > src/main/java/com/chatapp/ChatApplication.java << 'EOF'
package com.chatapp;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ChatApplication {
    public static void main(String[] args) {
        SpringApplication.run(ChatApplication.class, args);
    }
}
EOF

# WebSocket config
cat > src/main/java/com/chatapp/config/WebSocketConfig.java << 'EOF'
package com.chatapp.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.*;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/chat").setAllowedOriginPatterns("*").withSockJS();
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }
}
EOF

# Chat model
cat > src/main/java/com/chatapp/model/ChatMessage.java << 'EOF'
package com.chatapp.model;

public class ChatMessage {
    private String from;
    private String content;

    public ChatMessage() {}
    public ChatMessage(String from, String content) {
        this.from = from;
        this.content = content;
    }

    public String getFrom() { return from; }
    public void setFrom(String from) { this.from = from; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
}
EOF

# Chat controller
cat > src/main/java/com/chatapp/controller/ChatController.java << 'EOF'
package com.chatapp.controller;

import com.chatapp.model.ChatMessage;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;

@Controller
public class ChatController {

    @MessageMapping("/sendMessage")
    @SendTo("/topic/messages")
    public ChatMessage sendMessage(ChatMessage message) {
        return message;
    }
}
EOF

cd ../

# -------- Create Frontend --------
echo "💻 Creating React Frontend..."

if [ ! -d "$FRONTEND_DIR" ]; then
  npx create-react-app $FRONTEND_DIR
fi

cd $FRONTEND_DIR
npm install sockjs-client stompjs

# Replace App.js
cat > src/App.js << 'EOF'
import React, { useEffect, useState } from "react";
import SockJS from "sockjs-client";
import { over } from "stompjs";

let stompClient = null;

function App() {
  const [connected, setConnected] = useState(false);
  const [messages, setMessages] = useState([]);
  const [user, setUser] = useState("");
  const [input, setInput] = useState("");

  const connect = () => {
    let socket = new SockJS("http://localhost:8080/chat");
    stompClient = over(socket);
    stompClient.connect({}, () => {
      setConnected(true);
      stompClient.subscribe("/topic/messages", (msg) => {
        if (msg.body) {
          setMessages((prev) => [...prev, JSON.parse(msg.body)]);
        }
      });
    });
  };

  const sendMessage = () => {
    if (stompClient && input.trim()) {
      const chatMessage = { from: user, content: input };
      stompClient.send("/app/sendMessage", {}, JSON.stringify(chatMessage));
      setInput("");
    }
  };

  return (
    <div className="p-4">
      {!connected ? (
        <div>
          <input
            type="text"
            placeholder="Enter your name"
            value={user}
            onChange={(e) => setUser(e.target.value)}
          />
          <button onClick={connect}>Join Chat</button>
        </div>
      ) : (
        <div>
          <h2>Welcome, {user}</h2>
          <div className="chat-box" style={{ border: "1px solid gray", height: "300px", overflowY: "scroll" }}>
            {messages.map((msg, i) => (
              <p key={i}>
                <b>{msg.from}: </b> {msg.content}
              </p>
            ))}
          </div>
          <input
            type="text"
            placeholder="Type a message..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && sendMessage()}
          />
          <button onClick={sendMessage}>Send</button>
        </div>
      )}
    </div>
  );
}

export default App;
EOF

cd ../

# -------- Run Instructions --------
echo "✅ Setup complete!"
echo ""
echo "👉 To run backend: "
echo "   cd $BACKEND_DIR && mvn spring-boot:run"
echo ""
echo "👉 To run frontend: "
echo "   cd $FRONTEND_DIR && npm start"
echo ""
echo "Chat app will run at: http://localhost:3000"
