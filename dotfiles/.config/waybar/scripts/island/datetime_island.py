#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime

def now_text() -> str:
    """
    例：Sun 15 Feb | 19:03
    """
    return datetime.datetime.now().strftime("%b %d %a | %H:%M %p")