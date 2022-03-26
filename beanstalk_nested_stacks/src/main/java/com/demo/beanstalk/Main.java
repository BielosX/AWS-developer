package com.demo.beanstalk;

import com.google.gson.Gson;

import static spark.Spark.*;

public class Main {
    public static void main(String[] args) {
        String usersBucket = System.getenv("USERS_BUCKET");
        var gson = new Gson();
        var usersService = new UsersService(usersBucket, gson);
        port(5000);
        get("/status/health", (req, resp) -> {
            resp.status(200);
            return "OK";
        });
        get("/users", (req, resp) -> gson.toJson(usersService.getAll()));
        post("/users", (req, resp) -> {
            var payload = gson.fromJson(req.body(), UserCreateRequest.class);
            var user = usersService.addUser(payload);
            return gson.toJson(user);
        });
    }
}
