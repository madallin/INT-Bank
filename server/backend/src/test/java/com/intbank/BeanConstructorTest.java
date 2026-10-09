package com.intbank;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.stereotype.Component;

import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Spring can only build a bean with several constructors if one is marked {@code @Autowired}
 * (or there is a no-argument one). Several controllers broke this, so the server could not
 * start; this keeps it from happening again without needing a full application context.
 */
class BeanConstructorTest
{

    @Test
    void everyComponentHasAConstructorSpringCanUse() throws Exception
    {
        ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
        scanner.addIncludeFilter(new AnnotationTypeFilter(Component.class)); // also matches @Service, @RestController, ...
        List<String> broken = new ArrayList<>();
        int checked = 0;
        for (BeanDefinition definition : scanner.findCandidateComponents("com.intbank"))
        {
            Class<?> type = Class.forName(definition.getBeanClassName());
            Constructor<?>[] constructors = type.getDeclaredConstructors();
            checked++;
            if (constructors.length <= 1) continue;
            boolean marked = Arrays.stream(constructors).anyMatch(c -> c.isAnnotationPresent(Autowired.class));
            boolean noArgs = Arrays.stream(constructors).anyMatch(c -> c.getParameterCount() == 0);
            if (!marked && !noArgs) broken.add(type.getName());
        }
        assertTrue(checked > 40, "scan found only " + checked + " components");
        assertTrue(broken.isEmpty(), "Spring cannot choose a constructor for: " + broken);
    }
}
