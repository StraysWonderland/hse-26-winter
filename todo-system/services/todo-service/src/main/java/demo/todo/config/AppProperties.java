package demo.todo.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** All runtime configuration comes from the environment (12-factor, factor III). */
@ConfigurationProperties(prefix = "app")
public record AppProperties(String version, String natsUrl, Chaos chaos) {
    public record Chaos(double failureRate, long latencyMs) {}
}
