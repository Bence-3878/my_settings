int main(int argc, char **argv) {
    if (argc < 2)
        return 2;
    int a = 0, i = 0;
    while (argv[1][i] != '\0') {
        if (argv[1][i] >= '0' && argv[1][i] <= '9')
            a = a * 10 + argv[1][i] - '0';
        else if (argv[1][i] >= 'a' && argv[1][i] <= 'z')
            a = a * 10 + argv[1][i] - 'a';

        else if (argv[1][i] >= 'A' && argv[1][i] <= 'Z')
            a = a * 10 + argv[1][i] - 'A';
    }
    return a;
}
