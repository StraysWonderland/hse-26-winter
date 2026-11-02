package demo.activity.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(String version, String natsUrl, String natsSubject, String natsQueueGroup) {}
