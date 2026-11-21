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
      // ${user.keystore} may be undefined once the PEM bundle is in use; logging must not fail
      // startup in that case.
      String keyStore;
      try {
        keyStore = env.getProperty("server.ssl.key-store", "(not set)");
      } catch (IllegalArgumentException e) {
        keyStore = "(unresolvable: " + e.getMessage() + ")";
      }
      log.info("Configured server.ssl.key-store = {}", keyStore);
      log.info(
          "Configured server.ssl.bundle = {}", env.getProperty("server.ssl.bundle", "(not set)"));
      log.info(
          "Configured PEM certificate = {}",
          env.getProperty("spring.ssl.bundle.pem.gateway.keystore.certificate", "(not set)"));
    };
  }
}
