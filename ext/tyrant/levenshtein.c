#include <ruby.h>

static VALUE distance(VALUE module, VALUE rs1, VALUE rs2) {
    char* s1 = StringValueCStr(rs1);
    char* s2 = StringValueCStr(rs2);

    int l1 = strlen(s1);
    int l2 = strlen(s2);

    int i;

    int dists[l1 + 1][l2 + 1];
    for (i = 0; i <= l1; ++i) {
        dists[i][0] = i;
    }
    for (i = 0; i <= l2; ++i) {
        dists[0][i] = i;
    }

    for (i = 1; i <= l1; ++i) {
        char c1 = s1[i - 1];
        int j;
        for (j = 1; j <= l2; ++j) {
            char c2 = s2[j - 1];

            int replace = dists[i - 1][j - 1] + (c1 == c2 ? 0 : 1);
            int add = dists[i - 1][j] + 1;
            int delete = dists[i][j - 1] + 1;
            int min = replace;
            if (add < min) {
                min = add;
            }
            if (delete < min) {
                min = delete;
            }
            dists[i][j] = min;
        }
    }

    return INT2NUM(dists[l1][l2]);
}

void Init_levenshtein() {
    VALUE Levenshtein = rb_define_module("Levenshtein");
    rb_define_singleton_method(Levenshtein, "distance", distance, 2);
}
