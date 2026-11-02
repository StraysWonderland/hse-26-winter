package demo.todo.web;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class ChaosPolicyTest {

    @Test
    void neverFailsWhenRateIsZero() {
        assertFalse(new ChaosPolicy(0.0, 0, () -> 0.0).shouldFail());
    }

    @Test
    void failsWhenRandomIsBelowRate() {
        assertTrue(new ChaosPolicy(0.3, 0, () -> 0.1).shouldFail());
    }

    @Test
    void passesWhenRandomIsAboveRate() {
        assertFalse(new ChaosPolicy(0.3, 0, () -> 0.9).shouldFail());
    }

    @Test
    void inactiveByDefault() {
        assertFalse(new ChaosPolicy(0.0, 0, () -> 0.0).active());
    }
}
