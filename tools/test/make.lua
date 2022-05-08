local lm = require "luamake"



lm:source_set "testcpp" {
    includes = {
        "../../3rd/glm"
    },
    sources = {
        "main.cpp"
    }
}

lm:exe "testcpp"{
    deps = "testcpp"
}