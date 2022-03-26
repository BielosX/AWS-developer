package com.demo.beanstalk;

import lombok.Builder;
import lombok.Value;

import java.util.UUID;

@Value
@Builder
public class User {
    UUID id;
    String firstName;
    String lastName;
    long age;
    String address;
}
