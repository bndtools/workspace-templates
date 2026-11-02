## Demo Servlet

This is an example of a simple Web-application with a single Servlet showing a Hello World text in the browser. It helps with your first steps building an OSGi Web-Application with bnd / bndtools.

## Requirements

This template requires the following fragments, which are added automatically
when you add `demo-webapp` to a workspace:
- `osgi` (contains the OSGi R8 dependencies)
- `osgi-testing` (adds JUnit 5 and OSGi testing support)

Java 17 or newer is required to build and run the example.

See the main index https://raw.githubusercontent.com/bndtools/workspace-templates/refs/heads/master/index.bnd for a list of available templates and check out the page about [template fragments](https://bnd.bndtools.org/chapters/620-template-fragments.html).

## Running in Eclipse

After this project is in your workspace, open `launch.bndrun`, resolve it if
needed, and click **Debug OSGi** to start the application. An HTTP server starts
on port 8080. Open http://localhost:8080/example in your browser to trigger
`ExampleServlet.java`.

## Troubleshooting:

Depending on your workspace you may need to press the `Resolve` button inside the `launch.bndrun` editor or change some configuration there.

See https://bnd.bndtools.org/chapters/300-launching.html


## Running on the bnd CLI (Command Line Interface)

Install the [bnd CLI](https://bnd.bndtools.org/chapters/120-install.html) to
start this web app from the command line:

```
bnd add workspace -f demo-webapp myworkspace
cd myworkspace/org.bndtools.demo.webapp
bnd build
bnd resolve resolve -W launch.bndrun
bnd run launch.bndrun
```


More info on the used bnd CLI commands:

- `bnd add workspace` https://bnd.bndtools.org/commands/add.html
- `bnd build` https://bnd.bndtools.org/chapters/400-commands.html
- `bnd run` https://bnd.bndtools.org/commands/build.html
