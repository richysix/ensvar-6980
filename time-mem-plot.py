# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///

import argparse

def main() -> None:
    print("Hello from time-mem-plot.py!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('input_files', nargs='*', metavar='FILE',
        type=str, default=sys.stdin, 
        help='Input matrix files')
    parser.add_argument('--output_base', metavar='OUT FILE BASE',
        type=str, default="agg", 
        help='Base file name for the output networks')
    parser.add_argument('--annotation', metavar='ANNOTATION FILE',
        type=str, default="annotation.txt", 
        help='Gene annotation file')
    parser.add_argument('--orderings', metavar='INT',
        type=int, default=10, 
        help='Number of different file orderings to do')
    parser.add_argument('--debug', action='count', default=0,
        help='Prints debugging information')
    params = parser.parse_args()
    main(params)