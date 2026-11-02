package demo.todo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class NatsConfig {

    @Bean(destroyMethod = "close")
    NatsClient natsClient(AppProperties props) {
        return new NatsClient(props.natsUrl(), "todo-service/" + Instance.HOSTNAME);
    }
}
