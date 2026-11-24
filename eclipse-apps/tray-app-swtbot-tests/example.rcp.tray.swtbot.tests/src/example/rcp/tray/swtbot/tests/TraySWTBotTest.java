/*******************************************************************************
 * Copyright (c) 2026 Kirschners GmbH and others.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which accompanies this distribution,
 * and is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ******************************************************************************/

package example.rcp.tray.swtbot.tests;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.InputStream;
import java.net.URI;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.channels.OverlappingFileLockException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.CodeSource;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;
import org.eclipse.swtbot.swt.finder.SWTBot;
import org.eclipse.swtbot.swt.finder.junit.SWTBotJunit4ClassRunner;
import org.eclipse.swtbot.swt.finder.waits.DefaultCondition;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.osgi.framework.Bundle;
import org.osgi.framework.FrameworkUtil;

@RunWith(SWTBotJunit4ClassRunner.class)
public class TraySWTBotTest {
	private static final long TIMEOUT_MS = 60_000;

	@Test
	public void realTrayMenusDialogsAndExit() throws Exception {
		String os = System.getProperty("os.name").toLowerCase();
		boolean windows = os.contains("windows");
		if (!windows && !os.contains("linux")) {
			fail("Native tray automation is not yet available on " + System.getProperty("os.name"));
		}
		Thread main = Thread.getAllStackTraces().keySet().stream()
				.filter(thread -> "main".equals(thread.getName()))
				.findFirst()
				.orElseThrow(() -> new IllegalStateException("Application main thread not found"));
		Display display = waitForDisplay(main);
		SWTBot bot = new SWTBot();
		bot.waitUntil(new DefaultCondition() {
			@Override
			public boolean test() {
				String[] tooltip = { null };
				display.syncExec(() -> {
					Tray tray = display.getSystemTray();
					if (tray != null && tray.getItemCount() == 1) {
						tooltip[0] = tray.getItem(0).getToolTipText();
					}
				});
				return "Tray App".equals(tooltip[0]);
			}

			@Override
			public String getFailureMessage() {
				return "Expected one tray item with tooltip 'Tray App'";
			}
		}, TIMEOUT_MS);
		ProcessBuilder secondInstance = secondInstanceBuilder();
		assertSecondInstanceRejected(secondInstance);

		String driver;
		String resource = windows ? "windows_tray.ps1" : "linux_tray.py";
		try (InputStream input = TraySWTBotTest.class.getResourceAsStream("/native/" + resource)) {
			if (input == null) {
				throw new IllegalStateException("Native tray driver missing from test bundle");
			}
			driver = new String(input.readAllBytes(), StandardCharsets.UTF_8);
		}
		ProcessBuilder nativeDriver;
		if (windows) {
			Path script = Path.of("generated", "native", resource).toAbsolutePath();
			Files.createDirectories(script.getParent());
			Files.writeString(script, driver, StandardCharsets.UTF_8);
			nativeDriver = new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive",
					"-ExecutionPolicy", "Bypass", "-File", script.toString());
			nativeDriver.environment().put("NATIVE_TRAY_APP_PID", Long.toString(ProcessHandle.current().pid()));
		} else {
			nativeDriver = new ProcessBuilder("python3", "-c", driver);
		}
		Process process = nativeDriver.redirectErrorStream(true).start();
		long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(120);
		while (process.isAlive()) {
			long remaining = deadline - System.nanoTime();
			if (remaining <= 0) {
				process.destroyForcibly();
				fail("Native tray driver timed out");
			}
			try {
				process.waitFor(remaining, TimeUnit.NANOSECONDS);
			} catch (InterruptedException interrupted) {
				// Exiting the application interrupts the tester before its child reports.
				if (!display.isDisposed()) {
					process.destroyForcibly();
					throw interrupted;
				}
			}
		}
		String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
		assertEquals("Native tray driver failed:\n" + output, 0, process.exitValue());
		assertTrue("Native tray driver did not report completed interactions:\n" + output,
				output.contains("Native " + (windows ? "Windows" : "Linux") + " tray menus, dialogs and Exit passed"));
		assertLockReleasedAfterExitAndCrash(secondInstance);
	}

	private static ProcessBuilder secondInstanceBuilder() throws Exception {
		List<String> classpath = new ArrayList<>();
		Bundle self = FrameworkUtil.getBundle(TraySWTBotTest.class);
		for (Bundle bundle : self.getBundleContext().getBundles()) {
			String name = bundle.getSymbolicName();
			if (name == null || !(name.equals(self.getSymbolicName()) || name.equals("example.rcp.tray")
					|| name.equals("org.eclipse.equinox.app") || name.equals("org.eclipse.swt")
					|| name.startsWith("org.eclipse.swt.gtk.") || name.startsWith("org.eclipse.swt.win32.")
					|| name.startsWith("org.eclipse.swt.cocoa."))) {
				continue;
			}
			String location = bundle.getLocation().replaceFirst("^(?:initial@)?reference:", "");
			if (location.startsWith("file:")) {
				classpath.add(Path.of(URI.create(location)).toString());
			}
		}
		CodeSource framework = Bundle.class.getProtectionDomain().getCodeSource();
		if (framework == null || !"file".equals(framework.getLocation().getProtocol())) {
			throw new IllegalStateException("Cannot locate the OSGi framework for the second-process test");
		}
		classpath.add(Path.of(framework.getLocation().toURI()).toString());
		String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
		return new ProcessBuilder(java, "-Duser.home=" + System.getProperty("user.home"), "-cp",
				String.join(File.pathSeparator, classpath), SecondInstanceProbe.class.getName())
				.redirectErrorStream(true);
	}

	private static void assertSecondInstanceRejected(ProcessBuilder builder) throws Exception {
		Process process = builder.start();
		if (!process.waitFor(15, TimeUnit.SECONDS)) {
			process.destroyForcibly();
			fail("Second application did not reject the concurrent launch");
		}
		String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
		assertEquals("Second application did not reject the concurrent launch:\n" + output, 0, process.exitValue());
		assertTrue("Second application did not report lock rejection:\n" + output,
				output.contains("Second application rejected"));
	}

	private static void assertLockReleasedAfterExitAndCrash(ProcessBuilder builder) throws Exception {
		Path lockPath = Path.of(System.getProperty("user.home"), ".example-rcp-tray.lock");
		waitForLock(lockPath, false, null);
		List<String> command = new ArrayList<>(builder.command());
		command.add("run");
		Process restarted = new ProcessBuilder(command).redirectErrorStream(true).start();
		try {
			waitForLock(lockPath, true, restarted);
		} finally {
			restarted.destroyForcibly();
			restarted.waitFor();
		}
		waitForLock(lockPath, false, null);
	}

	private static void waitForLock(Path path, boolean held, Process process) throws Exception {
		long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(15);
		try (FileChannel channel = FileChannel.open(path, StandardOpenOption.WRITE)) {
			while (System.nanoTime() < deadline) {
				if (process != null && !process.isAlive()) {
					String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
					fail("Restarted application exited before acquiring the lock:\n" + output);
				}
				boolean available;
				try (FileLock lock = channel.tryLock()) {
					available = lock != null;
				} catch (OverlappingFileLockException overlap) {
					available = false;
				}
				if (available != held) {
					return;
				}
				Thread.sleep(100);
			}
		}
		fail("Application lock did not become " + (held ? "held" : "available"));
	}

	private static Display waitForDisplay(Thread main) throws InterruptedException {
		long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(TIMEOUT_MS);
		while (System.nanoTime() < deadline) {
			Display display = Display.findDisplay(main);
			if (display != null && !display.isDisposed()) {
				boolean[] ready = { false };
				try {
					display.syncExec(() -> {
						Tray tray = display.getSystemTray();
						if (tray != null) {
							TrayItem[] items = tray.getItems();
							ready[0] = items.length > 0;
						}
					});
				} catch (NullPointerException ignored) {
					// Display.findDisplay can see the Display during its constructor.
				}
				if (ready[0]) {
					return display;
				}
			}
			Thread.sleep(100);
		}
		throw new IllegalStateException("Application did not create its SWT tray within " + TIMEOUT_MS + " ms");
	}
}
