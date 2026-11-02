package demo.todo.web;

import java.util.function.DoubleSupplier;

public record ChaosPolicy(double failureRate, long latencyMs, DoubleSupplier random) {
    public boolean shouldFail() {
        return failureRate > 0 && random.getAsDouble() < failureRate;
    }

    public boolean active() {
        return failureRate > 0 || latencyMs > 0;
    }
}
