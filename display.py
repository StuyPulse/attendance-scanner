import curses
import threading

def synchronized(f):
    f.__lock__ = threading.Lock()

    def wrapper(*args, **kwargs):
        with f.__lock__:
            return f(*args, **kwargs)

    return wrapper

class ScannerDisplay:
    RED = curses.COLOR_RED
    GREEN = curses.COLOR_GREEN
    YELLOW = curses.COLOR_YELLOW
    MAGENTA = curses.COLOR_MAGENTA
    WHITE = curses.COLOR_WHITE

    def __init__(self, stdscr, prompt=""):
        curses.start_color()
        curses.use_default_colors()
        for x in range(curses.COLORS):
            curses.init_pair(x, x, -1)

        self.stdscr = stdscr
        self.messages = []
        self.message_buffer = []
        self.input_buffer = ""
        self.prompt = prompt

        messages_hwyx = (curses.LINES - 2, curses.COLS, 0, 0)
        status_hwyx = (curses.LINES - 2, 0)
        input_hwyx = (curses.LINES - 1, 0)

        self.win_messages = stdscr.derwin(*messages_hwyx)
        self.win_status_bar = stdscr.derwin(*status_hwyx)
        self.win_input = stdscr.derwin(*input_hwyx)
        self.redraw()

    def resize(self):
        height, width = self.stdscr.getmaxyx()
        self.win_input.mvwin(height - 1, 0)
        self.win_input.resize(1, width)

        self.win_status_bar.mvwin(height - 2, 0)
        self.win_status_bar.resize(1, width)

        self.win_messages.resize(height - 2, width)

        for message in self.messages:
            self.add_message_buffer(message[0], message[1])
        self.redraw()

    def redraw(self):
        height, width = self.stdscr.getmaxyx()
        self.stdscr.clear()
        self.stdscr.refresh()

        self.win_status_bar.hline(0, 0, "-", width)
        self.win_status_bar.refresh()

        self.redraw_messages()
        self.redraw_input()

    def redraw_messages(self):
        height, width = self.win_messages.getmaxyx()
        self.win_messages.clear()

        start = max(len(self.message_buffer) - height, 0)

        for x in range(min(height, len(self.message_buffer))):
            message = self.message_buffer[start]
            color = curses.color_pair(message[1])
            if message[1] != 0:
                color |= curses.A_BOLD
            self.win_messages.addstr(x, 0, message[0], color)
            start += 1

        self.win_messages.refresh()

    def redraw_input(self):
        height, width = self.win_input.getmaxyx()
        self.win_input.clear()

        combined = self.prompt + self.input_buffer
        start = max(len(combined) - width + 1, 0)
        self.win_input.addstr(0, 0, combined[start:])
        self.win_input.cursyncup()
        self.win_input.refresh()

    @synchronized
    def add_message(self, message, color=0):
        self.messages.append((message, color))
        self.add_message_buffer(message, color)
        self.redraw()

    def add_message_buffer(self, message, color=0):
        message = message.replace("\n", " ")
        _, width = self.stdscr.getmaxyx()

        while len(message) >= width:
            self.message_buffer.append((message[:width], color))
            message = message[width:]

        if message:
            self.message_buffer.append((message, color))

    def get_input(self, prompt="", hidden=False, _filter=None):
        if hidden:
            curses.noecho()

        if prompt:
            self.prompt = prompt
        self.redraw_input()
        last = -1
        while True:
            last = self.stdscr.getch()
            if last == ord('\n') and len(self.input_buffer) > 0:
                tmp = self.input_buffer
                self.input_buffer = ""
                self.redraw_input()
                self.win_input.cursyncup()
                return tmp
            elif last == curses.KEY_BACKSPACE or last == 127:
                if len(self.input_buffer) > 0:
                    self.input_buffer = self.input_buffer[:-1]
            elif last == curses.KEY_RESIZE:
                self.resize()
            elif _filter is None:
                if 32 <= last <= 126:
                    self.input_buffer += chr(last)
            elif _filter(chr(last)):
                self.input_buffer += chr(last)
            if not hidden:
                self.redraw_input()

    def get_number(self, prompt="", hidden=False):
        return int(self.get_input(prompt=prompt, hidden=hidden, _filter=str.isdigit))

    def set_prompt(self, prompt):
        self.prompt = prompt
        self.redraw_input()

    def close(self):
        curses.endwin()
        del self.stdscr
        del self.win_messages
        del self.win_input
