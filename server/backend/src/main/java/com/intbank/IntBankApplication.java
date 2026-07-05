package com.intbank;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class IntBankApplication
{

    public static void main(String[] args)
    {
        SpringApplication.run(IntBankApplication.class, args);
    }
}