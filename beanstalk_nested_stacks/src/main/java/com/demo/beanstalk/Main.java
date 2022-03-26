package com.demo.beanstalk;

import static spark.Spark.get;
import static spark.Spark.port;

public class Main {
    public static void main(String[] args) {
        port(5000);
        get("/status/health", (req, resp) -> {
            resp.status(200);
            return "OK";
        });
    }
}
