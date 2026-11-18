package com.example;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class Application {

  private static final Logger log = LoggerFactory.getLogger(Application.class);

  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }

  @GetMapping("/")
  public String hello() {
    return "TLS demo is up\n";
  }

  @Bean
  ApplicationRunner showConfiguredSsl(Environment env) {
    return args -> {
      log.info(
          "Configured server.ssl.key-store = {}",
          env.getProperty("server.ssl.key-store", "(not set)"));
      log.info(
          "Configured server.ssl.bundle = {}", env.getProperty("server.ssl.bundle", "(not set)"));
      log.info(
          "Configured PEM certificate = {}",
          env.getProperty("Spring.ssl.bundle.pem.gateway.keystore.certificate", "(not set)"));
    };
  }
}
