package com.dylanseidt.demospring.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/hello")
    public String helloGET() {
        return "Hello world!";
    }

    @GetMapping("/healthCheck")
    public String healthCheckGET() {
        return "Healthy!";
    }

}
