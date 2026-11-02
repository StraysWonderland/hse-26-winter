package demo.todo.web;

import demo.todo.config.AppProperties;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.concurrent.ThreadLocalRandom;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Fault injection for resilience demos: CHAOS_LATENCY_MS delays, CHAOS_FAILURE_RATE answers 503.
 * Only /api/** is affected, so health probes stay green and the failure is "partial".
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
class ChaosFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(ChaosFilter.class);

    private final ChaosPolicy policy;

    ChaosFilter(AppProperties props) {
        this.policy = new ChaosPolicy(props.chaos().failureRate(), props.chaos().latencyMs(),
                () -> ThreadLocalRandom.current().nextDouble());
        if (policy.active()) {
            log.warn("chaos enabled: failureRate={} latencyMs={}", policy.failureRate(), policy.latencyMs());
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !policy.active() || !request.getRequestURI().startsWith("/api/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (policy.latencyMs() > 0) {
            try {
                Thread.sleep(policy.latencyMs());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        if (policy.shouldFail()) {
            response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"injected failure (CHAOS_FAILURE_RATE)\"}");
            return;
        }
        chain.doFilter(request, response);
    }
}
