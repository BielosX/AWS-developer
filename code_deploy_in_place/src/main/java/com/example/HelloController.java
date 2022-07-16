package com.example;

import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HelloController {

    @GetMapping(path = "/hello")
    public ResponseEntity<String> getHello() {
        return ResponseEntity.ok("Hello");
    }
}
