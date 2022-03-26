package com.demo.beanstalk;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.S3ObjectInputStream;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import com.google.gson.Gson;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.UUID;
import java.util.stream.Collectors;

public class UsersService {
    private final AmazonS3 client;
    private final String bucketName;
    private final Gson gson;

    public UsersService(String bucketName, Gson gson) {
        this.client = AmazonS3Client.builder().build();
        this.bucketName = bucketName;
        this.gson = gson;
    }

    private User readUser(S3ObjectInputStream stream) {
        var reader = new BufferedReader(new InputStreamReader(stream));
        return gson.fromJson(reader, User.class);
    }

    public UsersResponse getAll() {
        var users = this.client.listObjects(this.bucketName)
                .getObjectSummaries()
                .stream()
                .map(S3ObjectSummary::getKey)
                .map(key -> readUser(this.client.getObject(this.bucketName, key).getObjectContent()))
                .collect(Collectors.toList());
        return new UsersResponse(users);
    }

    public User addUser(UserCreateRequest request) {
        var id = UUID.randomUUID();
        var user = User.builder()
                .id(id)
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .address(request.getLastName())
                .age(request.getAge())
                .build();
        var jsonUser = gson.toJson(user);
        this.client.putObject(this.bucketName, id.toString(), jsonUser);
        return user;
    }
}
