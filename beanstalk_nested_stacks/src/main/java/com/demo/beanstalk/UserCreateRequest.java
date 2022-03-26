package com.demo.beanstalk;

import lombok.Value;

@Value
public class UserCreateRequest {
    String firstName;
    String lastName;
    long age;
    String address;
}
