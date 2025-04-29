After this project is in your workspace, go to `File / New / Bnd OSGi Project` and the select `Examples / Simple HTTP Servlet` to create your own project based on this template with the actual servlet in it.

In this project, open the launch.bndrun and click 'Debug OSGi' to start the application.
An HTTP Server is started.
Then open http://localhost:8080/example in your browser to trigger `ExampleServlet.java`.

## Troubleshooting:

Depending on your workspace you may need to press the `Resolve` button inside the launch.bndrun editor or change some configuration there.

See https://bnd.bndtools.org/chapters/300-launching.html