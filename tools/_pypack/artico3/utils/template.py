"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Preprocessor to parse source files.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

Author      : Christoph Rüthing, University of Paderborn

------------------------------------------------------------------------
"""

import re

import artico3.utils.shutil2 as shutil2

#
# Internal method used for replacing each occurence of a generate
# statement in the source file.
#
#   scope - list of dictionaries including the used keys
#
def _gen_preproc(scope):
    def _gen_(m):
        values = [_[m.group("key")] for _ in scope if m.group("key") in _]

        if not values:
            return m.string[m.start():m.end()]
        else:
            value = values[0]

        if type(value) is bool:
            return m.group("data") if value else ""

        if type(value) is int:
            value = [{} for _ in range(value)]

        if type(value) is not list:
            return m.string[m.start():m.end()]

        data = ""
        i = 0
        for r in value:
            local = {"_i" : i}
            local.update(r)
            nscope = [local] + scope

            if m.group("cond") is not None and not eval(m.group("cond"), local):
                continue

            # recursively processing nested generates which use equal signs to
            # indicate the nesting, e.g. <a3<= ... =>a3>
            od = "<a3<" + "=" * len(scope)
            cd = "=" * len(scope) + ">a3>[\n]"
            reg = od + r"generate for (?P<key>[A-Za-z0-9_]*?)(?:\((?P<cond>.*?)\))?" + cd + r"\n?(?P<data>.*?)" + od + r"end generate" + cd
            ndata = re.sub(reg, _gen_preproc(nscope), m.group("data"), 0, re.DOTALL)

            # processing keys which are replaced by values from the scope, e.g.
            # <a3<...>a3>
            reg = r"<a3<(?P<key>[A-Za-z0-9_]+)(?:\((?P<join>.*?)\))?(?:\|(?P<format>.*))?>a3>"
            def repl(m):
                values = [_[m.group("key")] for _ in nscope if m.group("key") in _]

                if not values:
                    return "<a3<" + m.group("key") + ">a3>"
                else:
                    if m.group("format") is None:
                        return str(values[0])
                    else:
                        return m.group("format").format(values[0])
            ndata = re.sub(reg, repl, ndata)

            # processing optional character which is not printed in the last
            # iteration of the generation
            reg = r"<a3<c(?P<data>.)>a3>"
            if i < len(value) - 1:
                ndata = re.sub(reg, "\g<data>", ndata)
            else:
                ndata = re.sub(reg, "", ndata)

            if ndata.count("\n") > 1:
                ndata += "\n"

            data += ndata
            i += 1

        return data

    return _gen_

#
# Internal method used for replacing each occurence of an if
# statement in the source file.
#
#   d - dictionary including the used keys
#
def _if_preproc(scope):
    def _gen_(m):
        eval_string="{} {} {}".format(m.group("key"), m.group("comp"), m.group("value"))

        d = scope[0]

        if eval(eval_string, d):
            local = {}
            nscope = scope + [local]

            od = r"<a3<" + r"=" * len(scope)
            cd = r"=" * len(scope) + r">a3>[\n]"
            reg = od + r"if (?P<key>[A-Za-z0-9_]*?)(?P<comp>[<>=!]*?)(?P<value>[A-Za-z0-9_\"]*?)" + cd + r"\n?(?P<data>.*?)" + od + r"end if" + cd

            return re.sub(reg, _if_preproc(nscope), m.group("data"), 0, re.DOTALL)

        else:
            return ""

    return _gen_

#
# Preprocesses the given file using a dictionary containing keys and
# a list of values.
#
#   filepath   - path to the file to preprocess
#   dictionary - dictionary containing all keys
#   mode       - print or overwrite to print to stdout or overwrite
#
def preproc(filepath, dictionary, mode, force=False):
    with open(filepath, "r") as file:
        try:
            data = file.read()
        except Exception as ex:
            return

    if "<a3<artico3_preproc>a3>" not in data and not force:
        return
    else:
        data = re.sub(r"<a3<artico3_preproc>a3>[\n]", "", data)

    # generate syntax: <a3<generate for KEY(OPTIONAL = CONDITION)>a3> ... <a3<end generate>a3>
    # used to automatically generate several lines of code
    reg = r"<a3<generate for (?P<key>[A-Za-z0-9_]*?)(?:\((?P<cond>.*?)\))?>a3>\n?(?P<data>.*?)<a3<end generate>a3>[\n]"
    data = re.sub(reg, _gen_preproc([dictionary]), data, 0, re.DOTALL)

    # if syntax: <a3<if KEY OPERATOR VALUE>a3> ... <a3<end if>a3>
    # used to conditionally include or exclude code fragments
    reg = r"<a3<if (?P<key>[A-Za-z0-9_]*?)(?P<comp>[<>=!]*?)(?P<value>[A-Za-z0-9_\"]*?)>a3>\n?(?P<data>.*?)<a3<end if>a3>[\n]"
    data = re.sub(reg, _if_preproc([dictionary]), data, 0, re.DOTALL)

    # global keys not inside generate
    reg = r"<a3<(?P<key>[A-Za-z0-9_]+)(?:\|(?P<format>.*))?>a3>"
    def repl(m):
        if m.group("key") in dictionary:
            if m.group("format") is None:
                return str(dictionary[m.group("key")])
            else:
                if type(dictionary[m.group("key")]) is list:
                    return m.group("format").format(*tuple(dictionary[m.group("key")]))
                else:
                    return m.group("format").format(dictionary[m.group("key")])
        else:
            return m.string[m.start():m.end()]
    data = re.sub(reg, repl, data)
    #~ print(data)
    #~ input()

    if mode == "print":
        print(data)
    elif mode == "overwrite":
        with open(filepath, "w") as file:
            file.write(data)

#
# Preprocesses the given file by replacing the file by its sources.
#
#   filepath   - path to the file to preprocess
#   dictionary - dictionary containing all keys
#
def precopy(filepath, dictionary, link):
    reg = r"^<a3<generate_for_(?P<key>[A-Za-z0-9_]+)>a3>"
    m = re.match(reg, shutil2.basename(filepath))

    if m is None:
        return
    else:
        shutil2.remove(filepath)

    if m.group("key") in dictionary:
        for f in dictionary[m.group("key")]:
            if link:
                shutil2.linktree(f, shutil2.dirname(filepath))
            else:
                shutil2.copytree(f, shutil2.dirname(filepath), True)

#
# Preprocesses the given file by renaming it.
#
#   filepath   - path to the file to preprocess
#   dictionary - dictionary containing all keys
#
def prefile(filepath, dictionary):
    old = shutil2.basename(filepath)

    reg = r"<a3<(?P<key>[A-Za-z0-9_]+)>a3>"
    def repl(m):
        if m.group("key") in dictionary:
            return str(dictionary[m.group("key")])
        else:
            return m.string[m.start():m.end()]
    new = re.sub(reg, repl, old)

    if (new != old):
        old = shutil2.join(shutil2.dirname(filepath), old)
        new = shutil2.join(shutil2.dirname(filepath), new)
        if shutil2.exists(new):
            shutil2.rmtree(new)
        shutil2.rename(old, new)

#
# Preprocesses the given directory by renaming it.
#
#   dirpath    - path to the file to preprocess
#   dirs       - dirs of walk function
#   dictionary - dictionary containing all keys
#
def predirectory(dirpath, dirs, dictionary):
    old = shutil2.basename(dirpath)

    reg = r"<a3<(?P<key>[A-Za-z0-9_]+)>a3>"
    def repl(m):
        if m.group("key") in dictionary:
            return str(dictionary[m.group("key")])
        else:
            return m.string[m.start():m.end()]
    new = re.sub(reg, repl, old)

    if (new != old):
        dirs.remove(old)
        dirs.append(new)
        old = shutil2.join(shutil2.dirname(dirpath), old)
        new = shutil2.join(shutil2.dirname(dirpath), new)
        if shutil2.exists(new):
            shutil2.rmtree(new)
        shutil2.rename(old, new)

#
# Generates the template given using a dictionary containing keys and
# a list of values.
#
#   filepath   - path to template directory
#   dictionary - dictionary containing all keys
#   mode       - print or overwrite to print to stdout or overwrite
#
def generate(filepath, dictionary, mode, link = False):
    def pc(f): return precopy(f, dictionary, link)
    shutil2.walk(filepath, pc)

    def pf(f): return prefile(f, dictionary)
    def pd(d, dirs): return predirectory(d, dirs, dictionary)
    shutil2.walk(filepath, pf, pd)

    def pp(f): return preproc(f, dictionary, mode)
    shutil2.walk(filepath, pp)
