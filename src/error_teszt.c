int main(int argc, char ** argv) {
    if (argc < 2) 
        return 2;
    int a = 0;
    for (int i = 0; argv[1][i] >= '0' && argv[1][i] <= '9' ; i++) {
    a *= 10;
    a += argv[1][i] - '0';}
    return a;
}
