# FourQ Side-Channel Analysis (SCA)
This is the source code of my master thesis which I wrote to obtain my Computer Science Master Degree. 
It could be useful for others to get a better idea of what a convenient structure would be when writing a big paper in LaTeX.

## Structure
* `/code`: contains the Python code used to perform the Online Template Attack (OTA)
* `/report`: contains the LaTeX source of the thesis.
* `/vhdl`: contains the source code for both the main and controller components of the FPGA.

## Building Requirements
Assuming Windows OS, make sure to have the following installed:
* A Python installation (e.g. [Anaconda](https://www.anaconda.com/distribution/#download-section)).
    * Assuming the default installation location of Anaconda, add the following directories to Windows Path environment variable:
	* `C:\ProgramData\Anaconda3\Scripts`
	* `C:\ProgramData\Anaconda3`
* Pygmentize
	* At Command Prompt, run `pip install Pygments`
* [MikTex](https://miktex.org/download)
* [Visual Studio Code](https://code.visualstudio.com/download)
	* [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)

## Building
The preferred editor is `vscode`, using the `Latex-Workshop` extension.
To get this up and running, follow the guide [installation guide](https://github.com/James-Yu/LaTeX-Workshop/wiki/Install). In short, this boils down to:
* Installing `latexmk` through MikTeX (i.e. MikTeX Console -> Packages -> `latexmk` -> install)
* Set the default PDF view as `tab`

As we make use of the `minted` package, we need to build using the `--shell-escape` flag.
in `vscode`, go to `file -> preferences -> settings` and search for `latex-workshop.latex.recipes`.
Click on `Edit in settings.json`, and add the following within the JSON object:
```JSON
// in USER SETTINGS add the following
"latex-workshop.latex.tools": [
    {
        "name": "latexmk",
        "command": "latexmk",
        "args": [
            "-synctex=1",
            "-interaction=nonstopmode",
            "-file-line-error",
            "-pdf",
            "--shell-escape", // added arg to default
            "%DOC%"
        ]
    },
    {
        "name": "pdflatex",
        "command": "pdflatex",
        "args": [
            "-synctex=1",
            "-interaction=nonstopmode",
            "-file-line-error",
            "--shell-escape", // added arg to default
            "%DOC%"
        ]
    },
    {
        "name": "bibtex",
        "command": "bibtex",
        "args": [
            "%DOCFILE%"
        ]
    }
],
"latex-workshop.view.pdf.viewer": "tab"
```
Now, open the root file of the thesis, click on the *TeX sidebar*.
Click on `Build LaTeX project` and select the `Recipe: latexmk`. This will start building the thesis.