#!/usr/bin/env python3
"""Builds recorder.html from recorder.template.html and the code it shares with booth.html.

booth.html is the source of the "Wader Voice Booth" page on claude.ai (it stores the takes where
Claude can fetch them, but pages there can't use the microphone). recorder.html is the standalone
page that records with the microphone and saves the takes as one file for the booth. Both use the
same styles and the same audio code: everything between the ">>> shared" and "<<< shared" markers
in booth.html.

    python3 build.py
"""
import pathlib, re

here = pathlib.Path(__file__).parent
booth = (here / "booth.html").read_text()
css = re.search(r"<style>\n(.*?)</style>", booth, re.S).group(1)
js = re.search(r"  // >>> shared[^\n]*\n(.*?)  // <<< shared", booth, re.S).group(1)
out = (here / "recorder.template.html").read_text().replace("/*SHARED_CSS*/", css).replace("/*SHARED_JS*/", js.rstrip())
(here / "recorder.html").write_text(out)
print("recorder.html: %d bytes" % len(out))
