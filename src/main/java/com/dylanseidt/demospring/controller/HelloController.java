package com.dylanseidt.demospring.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String helloGET() {
        return "Welcome to the root again!";
    }

    @GetMapping("/healthCheck")
    public String healthCheckGET() {
        return "Healthy!";
    }

}
