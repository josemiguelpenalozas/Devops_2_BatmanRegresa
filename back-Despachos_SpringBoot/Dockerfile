#Multi-stage
#Stage 1
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY Springboot-API-REST-DESPACHO/pom.xml .
COPY Springboot-API-REST-DESPACHO/src ./src
RUN mvn clean package -DskipTests

#Stage 2
FROM eclipse-temurin:21-jdk
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","app.jar"]