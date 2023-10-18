/*Copyright 2019-2023 Kai D. Gonzalez*/

import std.stdio : writefln, writef;
import std.string : strip, split, join, startsWith;
import std.file : readText;

struct TParagraph
{
    string text;
}

struct TSection
{
    string title;
    TParagraph[] paragraphs;
    TSection[] subsections;
    int depth; // how deep to indent
}

struct TBook
{
    string title;
    TSection[] sections;
}

const char B_LEX_PARAGRAPH = '\n';
const char B_LEX_SECTION = ':';

enum bookLexerTokenType
{
    B_PLAINTEXT,
    B_SECTION_SEPARATOR,
    B_NEWLINE
}

// there aren't too many states for a book if you think about it,
// all you really need are states to collect titles (the first sentence of a
// plaintext file) and states to collect everything else, nothing really matters
// since everything's being put into a paragraph AND/OR a section
enum bookLexerState
{
    B_TITLE_STATE, // collecting the title
    B_PARAGRAPH_POTENTIAL_END, // when you make a newline in a paragraph, assume 
    // this is wrapped text, we won't IMMEDIATELY
    // close it off until there is another official newline
    B_PARAGRAPH_STATE, // collecting everything else
    B_SECTION_STATE, // collecting the titles of sections
}

bookLexerTokenType evaluate_type(char tok)
{
    switch (tok)
    {
    case B_LEX_PARAGRAPH:
        return bookLexerTokenType.B_NEWLINE;
    case B_LEX_SECTION:
        return bookLexerTokenType.B_SECTION_SEPARATOR;
    default:
        return bookLexerTokenType.B_PLAINTEXT;
    }
}

string strip_lines(string text)
{
    string[] lines = split(text, '\n');
    for (int i = 0; i < lines.length; i++)
    {
        lines[i] = strip(lines[i]);
    }
    return join(lines, '\n');
}

TBook t_create_book(string title)
{
    TBook book;
    t_set_book_header(&book, title);
    return book;
}

bool t_lex_endofstatment(string n, int i)
{
    return i == n.length;
}

void t_lex_verify(string stat)
{
    if (stat[stat.length - 1] != '\n')
    {
        writefln("error: no newline at the end of file", stat);
        throw new Exception("no newline at the end of file");
    }
}

TBook t_create_book_from_file(string path)
{
    TBook book;

    string text = readText(path);
    t_lex_verify(text);

    string tmp = "";

    TSection section = t_create_section("");
    bookLexerState state = bookLexerState.B_TITLE_STATE;

    for (int i = 0; i < text.length - 1; i++)
    {
        char tok = text[i];
        bookLexerTokenType type = evaluate_type(tok);

        if (type == bookLexerTokenType.B_NEWLINE)
        {
            if (state == bookLexerState.B_PARAGRAPH_POTENTIAL_END || startsWith(tmp, "\t")) {
                state = bookLexerState.B_SECTION_STATE;
                t_add_paragraph(&section, t_create_paragraph(strip_lines(tmp)));
                tmp = "";
                continue;
            }
            switch (state)
            {
            case bookLexerState.B_TITLE_STATE: // if it's the title
                state = bookLexerState.B_SECTION_STATE;
                t_set_book_header(&book, tmp);
                tmp = "";
                break;

            case bookLexerState.B_PARAGRAPH_STATE:
                if (strip(tmp).length >= 0)
                {
                    if (state == bookLexerState.B_PARAGRAPH_POTENTIAL_END)
                    {
                        writefln("hello");
                        tmp = "";
                        state = bookLexerState.B_SECTION_STATE;
                    }
                    else
                    {
                        writefln("12hello");
                        state = bookLexerState.B_PARAGRAPH_POTENTIAL_END;
                        tmp ~= tok;
                    }
                }
                else
                {
                    if (state == bookLexerState.B_PARAGRAPH_POTENTIAL_END)
                    {

                        state = bookLexerState.B_SECTION_STATE;
                        t_add_paragraph(&section, t_create_paragraph(strip_lines(tmp)));
                        t_add_section(&book, section);

                        section = t_create_section("");

                        tmp = "";
                    }
                }
                break;

            default:
                break;
            }

        }
        else if (type == bookLexerTokenType.B_SECTION_SEPARATOR
            && state == bookLexerState.B_SECTION_STATE)
        {
            writefln("section title: %s", tmp);
            t_set_section_header(&section, strip(tmp));
            state = bookLexerState.B_PARAGRAPH_STATE;
            tmp = "";
        }
        else
        {
            if (state == bookLexerState.B_PARAGRAPH_POTENTIAL_END && tok != '\n'
                && type == bookLexerTokenType.B_PLAINTEXT)
            { // if it was a plan to end the paragraph, there is no longer one
                state = bookLexerState.B_PARAGRAPH_STATE;
            }

            tmp ~= tok;
        }
    }

    if (tmp.length > 0)
    {
        if (state == bookLexerState.B_PARAGRAPH_POTENTIAL_END || state == bookLexerState
            .B_PARAGRAPH_STATE)
        {
            t_add_paragraph(&section, t_create_paragraph(strip_lines(tmp)));
            t_add_section(&book, section);
        }
    }
    writefln("Section: %s", section);

    return book;
}

void t_set_book_header(TBook* book, string title)
{
    book.title = title;
}

void t_add_subsection(TSection* section, TSection subsection)
{
    section.subsections ~= (subsection);
    section.depth = 1;
}

void t_set_section_header(TSection* section, string title)
{
    section.title = title;
}

void t_set_paragraph(TParagraph* paragraph, string text)
{
    paragraph.text = strip(text);
}

bool t_string_length_is_zero(string s)
{
    return strip(s).length == 0;
}

void t_increment_depth(TSection* t)
{
    t.depth++;
}

TParagraph t_create_paragraph(string text)
{
    TParagraph paragraph;
    t_set_paragraph(&paragraph, text);
    return paragraph;
}

int t_lex_count_tabs(string text)
{
    int count = 0;
    for (int i = 0; i < text.length; i++)
    {
        if (text[i] == '\t')
            count++;
    }
    return count;
}

TSection t_create_section(string title)
{
    TSection section;
    t_set_section_header(&section, title);
    section.depth = 1;
    return section;
}

TSection t_derive_section(TSection* parent, string title)
{
    TSection section = t_create_section(title);
    section.depth = parent.depth + 1;
    return section;
}

void t_add_paragraph(TSection* section, TParagraph paragraph)
{
    section.paragraphs ~= (paragraph);
}

void t_add_section(TBook* book, TSection section)
{
    section.depth = 1;
    book.sections ~= (section);
}

void t_fix_lines(string text, int depth = 0)
{
    string[] lines = split(text, '\n');

    foreach (string line; lines)
    {
        for (int i = 0; i < depth; i++)
        {
            writef("  ");
        }
        writefln("%s", line);
    }
}

void t_print_section(TSection* section)
{
    writef("%s\n", section.title);

    foreach (TParagraph paragraph; section.paragraphs)
    {
        t_fix_lines(paragraph.text, section.depth);
        writef("\n");
    }
    foreach (TSection subsection; section.subsections)
    {
        t_print_section(&subsection);
    }
}

void t_print_book(TBook* book)
{
    writef("%s\n----\n", book.title);
    foreach (TSection section; book.sections)
    {
        writef("%s\n", section.title);
        foreach (TParagraph paragraph; section.paragraphs)
        {
            t_fix_lines(paragraph.text, section.depth);
            writef("\n");

        }
        foreach (TSection subsection; section.subsections)
        {
            t_print_section(&subsection);

        }
    }
}

int main()
{
    TBook t;
    // t_set_book_header(&t, "My Amazing Book");

    // auto chap1 = t_create_section("Chapter 1");

    // auto pg1 = t_create_paragraph("this is chapter 1.\nthis is a simple test.");

    // auto chapsub = t_create_section("(section 1.1)");

    // auto pg2 = t_create_paragraph("this is section 1.1.\nthis is a simple test.");

    // auto chapsubsub = t_create_section("(section 1.1.1)");
    // auto pg3 = t_create_paragraph("this is section 1.1.1.\nthis is a simple test.");

    // t_add_paragraph(&chapsub, pg2);
    // t_add_paragraph(&chapsubsub, pg3);
    // t_add_paragraph(&chap1, pg1);

    // t_add_subsection(&chapsub, chapsubsub);

    // t_add_subsection(&chap1, chapsub);
    // t_add_section(&t, chap1);

    // // print the entire book
    // t_print_book(&t);

    TBook book = t_create_book_from_file("book.txt");
    t_print_book(&book);

    return 0;
}
