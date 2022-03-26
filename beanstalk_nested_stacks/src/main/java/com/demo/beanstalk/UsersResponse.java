package com.demo.beanstalk;

import lombok.Value;

import java.util.List;

@Value
public class UsersResponse {
    List<User> users;
}
