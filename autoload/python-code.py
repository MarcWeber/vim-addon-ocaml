# Copyright (C) <2003-2004> Stefano Zacchiroli <zack@bononia.it>
# initially written by him.
# mapping code can be found at ftplugin/ocaml.vim

import re
import os
import os.path
import string
import time
import vim

debug = False

class AnnExc(Exception):
    def __init__(self, reason):
        self.reason = reason

no_annotations = AnnExc("No annotations (.annot) file found")
annotation_not_found = AnnExc("No type annotation found for the given text")
definition_not_found = AnnExc("No definition found for the given text")
def malformed_annotations(lineno, reason):
    return AnnExc("Malformed .annot file (line = %d, reason = %s)" % (lineno,reason))

class Annotations:
    """
      .annot ocaml file representation

      File format (copied verbatim from caml-types.el)

      file ::= block *
      block ::= position <SP> position <LF> annotation *
      position ::= filename <SP> num <SP> num <SP> num
      annotation ::= keyword open-paren <LF> <SP> <SP> data <LF> close-paren

      <SP> is a space character (ASCII 0x20)
      <LF> is a line-feed character (ASCII 0x0A)
      num is a sequence of decimal digits
      filename is a string with the lexical conventions of O'Caml
      open-paren is an open parenthesis (ASCII 0x28)
      close-paren is a closed parenthesis (ASCII 0x29)
      data is any sequence of characters where <LF> is always followed by
           at least two space characters.

      - in each block, the two positions are respectively the start and the
        end of the range described by the block.
      - in a position, the filename is the name of the file, the first num
        is the line number, the second num is the offset of the beginning
        of the line, the third num is the offset of the position itself.
      - the char number within the line is the difference between the third
        and second nums.

      Possible keywords are \"type\", \"ident\" and \"call\".
    """

    def __init__(self):
        self.__filename = None  # last .annot parsed file
        self.__ml_filename = None # as above but s/.annot/.ml/
        self.__timestamp = None # last parse action timestamp
        self.__annot = {}
        self.__refs = {}
        self.__calls = {}
        self.__re = re.compile(
          '^"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)\s+"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)$')
        self.__re_int_ref = re.compile('^int_ref\s+(\w+)\s"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)')
        self.__re_def_full = re.compile(
          '^def\s+(\w+)\s+"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)\s+"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)$')
        self.__re_def = re.compile('^def\s+(\w+)\s"[^"]*"\s+(\d+)\s+(\d+)\s+(\d+)\s+')
        self.__re_ext_ref = re.compile('^ext_ref\s+(\S+)')
        self.__re_kw = re.compile('^(\w+)\($')

    def __parse(self, fname):
        try:
            f = open(fname)
            self.__annot = {} # erase internal mappings when file is reparsed
            self.__refs = {}
            self.__calls = {}
            line = f.readline() # position line
            lineno = 1
            while (line != ""):
                m = self.__re.search(line)
                if (not m):
                    raise malformed_annotations(lineno,"re doesn't match")
                line1 = int(m.group(1))
                col1 = int(m.group(3)) - int(m.group(2))
                line2 = int(m.group(4))
                col2 = int(m.group(6)) - int(m.group(5))
                while 1:
                    line = f.readline() # keyword or position line
                    lineno += 1
                    m = self.__re_kw.search(line)
                    if (not m):
                        break
                    desc = []
                    line = f.readline() # description
                    lineno += 1
                    if (line == ""): raise malformed_annotations(lineno,"no content")
                    while line != ")\n":
                        desc.append(string.strip(line))
                        line = f.readline()
                        lineno += 1
                        if (line == ""): raise malformed_annotations(lineno,"bad content")
                    desc = string.join(desc, "\n")
                    key = ((line1, col1), (line2, col2))
                    if (m.group(1) == "type"):
                        if not self.__annot.has_key(key):
                            self.__annot[key] = desc
                    if (m.group(1) == "call"): # region, accessible only in visual mode
                        if not self.__calls.has_key(key):
                            self.__calls[key] = desc
                    if (m.group(1) == "ident"):
                        m = self.__re_int_ref.search(desc)
                        if m:
                          line = int(m.group(2))
                          col = int(m.group(4)) - int(m.group(3))
                          name = m.group(1)
                        else:
                          line = -1
                          col = -1
                          m = self.__re_ext_ref.search(desc)
                          if m:
                            name = m.group(1)
                          else:
                            line = -2
                            col = -2
                            name = desc
                        if not self.__refs.has_key(key):
                          self.__refs[key] = (line,col,name)
            f.close()
            self.__filename = fname
            self.__ml_filename = vim.current.buffer.name
            self.__timestamp = int(time.time())
        except IOError:
            raise no_annotations

    def parse(self):
        try:
            annot_file = os.path.splitext(vim.current.buffer.name)[0] + ".annot"
            self.__parse(annot_file)
        except:
            (head,tail) = os.path.split(annot_file)
            annot_file = os.path.join(head, "_build/", tail)
            self.__parse(annot_file)

    def check_file(self):
        if vim.current.buffer.name == None:
            raise no_annotations
        if vim.current.buffer.name != self.__ml_filename or  \
          os.stat(self.__filename).st_mtime > self.__timestamp:
            self.parse()

    def get_type(self, (line1, col1), (line2, col2)):
        if debug:
            print line1, col1, line2, col2
        self.check_file()
        try:
            try:
              extra = self.__calls[(line1, col1), (line2, col2)]
              if extra == "tail":
                extra = " (* tail call *)"
              else:
                extra = " (* function call *)"
            except KeyError:
              extra = ""
            return self.__annot[(line1, col1), (line2, col2)] + extra
        except KeyError:
            raise annotation_not_found

    def get_ident(self, (line1, col1), (line2, col2)):
        if debug:
            print line1, col1, line2, col2
        self.check_file()
        try:
            (line,col,name) = self.__refs[(line1, col1), (line2, col2)]
            if line >= 0 and col >= 0:
              vim.command("normal "+str(line)+"gg"+str(col+1)+"|")
              #current.window.cursor = (line,col)
            if line == -2:
              m = self.__re_def_full.search(name)
              if m:
                l2 = int(m.group(5))
                c2 = int(m.group(7)) - int(m.group(6))
                name = m.group(1)
              else:
                m = self.__re_def.search(name)
                if m:
                  l2 = int(m.group(2))
                  c2 = int(m.group(4)) - int(m.group(3))
                  name = m.group(1)
                else:
                  l2 = -1
              if False and l2 >= 0:
                # select region
                if c2 == 0 and l2 > 0:
                  vim.command("normal v"+str(l2-1)+"gg"+"$")
                else:
                  vim.command("normal v"+str(l2)+"gg"+str(c2)+"|")
            return name
        except KeyError:
            raise definition_not_found

word_char_RE = re.compile("^[\w.]$")

  # TODO this function should recognize ocaml literals, actually it's just an
  # hack that recognize continuous sequences of word_char_RE above
def findBoundaries(line, col):
    """ given a cursor position (as returned by vim.current.window.cursor)
    return two integers identify the beggining and end column of the word at
    cursor position, if any. If no word is at the cursor position return the
    column cursor position twice """
    left, right = col, col
    line = line - 1 # mismatch vim/python line indexes
    (begin_col, end_col) = (0, len(vim.current.buffer[line]) - 1)
    try:
        while word_char_RE.search(vim.current.buffer[line][left - 1]):
            left = left - 1
    except IndexError:
        pass
    try:
        while word_char_RE.search(vim.current.buffer[line][right + 1]):
            right = right + 1
    except IndexError:
        pass
    return (left, right)

annot = Annotations() # global annotation object

def get_marks(mode):
    if mode == "visual":  # visual mode: lookup highlighted text
        (line1, col1) = vim.current.buffer.mark("<")
        (line2, col2) = vim.current.buffer.mark(">")
    else: # any other mode: lookup word at cursor position
        (line, col) = vim.current.window.cursor
        (col1, col2) = findBoundaries(line, col)
        (line1, line2) = (line, line)
    begin_mark = (line1, col1)
    end_mark = (line2, col2 + 1)
    return (begin_mark,end_mark)

def printOCamlType(mode):
    try:
        (begin_mark,end_mark) = get_marks(mode)
        print annot.get_type(begin_mark, end_mark)
    except AnnExc, exc:
        print exc.reason

def gotoOCamlDefinition(mode):
    try:
        (begin_mark,end_mark) = get_marks(mode)
        print annot.get_ident(begin_mark, end_mark)
    except AnnExc, exc:
        print exc.reason

def parseOCamlAnnot():
    try:
        annot.parse()
    except AnnExc, exc:
        print exc.reason
