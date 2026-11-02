package demo.todo.web;

import demo.todo.config.AppProperties;
import demo.todo.config.Instance;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Makes load balancing, scaling and rolling updates visible in the UI and with curl -i. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
class ServedByFilter extends OncePerRequestFilter {
    private final String version;

    ServedByFilter(AppProperties props) {
        this.version = props.version();
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        response.setHeader("X-Served-By", Instance.HOSTNAME);
        response.setHeader("X-App-Version", version);
        chain.doFilter(request, response);
    }
}
