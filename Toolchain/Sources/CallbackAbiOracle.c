/* Independent C call sites for a mixed record spilled after GP exhaustion.
 * The Zig 0.16 x64 caller misplaces the scalar following this record shape;
 * using Clang here keeps that caller defect out of the Silex ABI oracle.
 * This translation unit is linked only into compiler tests. */
typedef unsigned long long Word;
_Static_assert(sizeof(Word) == 8, "64-bit ABI oracle");
struct Mixed { Word tag; double value; };
#define ARGUMENTS Word, Word, Word, Word, Word, Word, Word, struct Mixed, Word
#if defined(__x86_64__) || defined(_M_X64)
#define WINDOWS_ABI __attribute__((ms_abi))
#else
#define WINDOWS_ABI
#endif

typedef Word (*Tail)(ARGUMENTS);
typedef Word (WINDOWS_ABI *WindowsTail)(ARGUMENTS);
typedef double (*Value)(ARGUMENTS);
typedef double (WINDOWS_ABI *WindowsValue)(ARGUMENTS);

Word silex_oracle_spilled_tail(void *callback, int windows) {
    struct Mixed record = {42, 3.5};
    if (windows) return ((WindowsTail)callback)(1, 2, 3, 4, 5, 6, 7, record, 99);
    return ((Tail)callback)(1, 2, 3, 4, 5, 6, 7, record, 99);
}
double silex_oracle_spilled_value(void *callback, int windows) {
    struct Mixed record = {42, 3.5};
    if (windows) return ((WindowsValue)callback)(1, 2, 3, 4, 5, 6, 7, record, 99);
    return ((Value)callback)(1, 2, 3, 4, 5, 6, 7, record, 99);
}
