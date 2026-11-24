/*******************************************************************************
 * Copyright (c) 2026 Kirschners GmbH and others.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which accompanies this distribution,
 * and is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ******************************************************************************/

package example.rcp.tray;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.channels.OverlappingFileLockException;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.TimeUnit;

import org.eclipse.equinox.app.IApplication;
import org.eclipse.equinox.app.IApplicationContext;
import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.GC;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;

public class TrayApplication implements IApplication {
	private volatile Display display;
	private Shell shell;

	@Override
	public Object start(IApplicationContext context) throws Exception {
		Path lockPath = Path.of(System.getProperty("user.home"), ".example-rcp-tray.lock");
		try (FileChannel channel = FileChannel.open(lockPath, StandardOpenOption.CREATE, StandardOpenOption.WRITE);
				FileLock lock = acquireLock(channel)) {
			display = new Display();
			try {
				shell = new Shell(display);
				Tray tray = display.getSystemTray();
				if (tray == null) {
					throw new IllegalStateException("System tray is unavailable.");
				}
				Image icon = createIcon(display);
				try {
					TrayItem item = new TrayItem(tray, SWT.NONE);
					try {
						item.setToolTipText("Tray App");
						item.setImage(icon);
						Menu leftMenu = createMenu(false);
						Menu contextMenu = createMenu(true);
						item.addListener(SWT.Selection, event -> leftMenu.setVisible(true));
						item.addListener(SWT.DefaultSelection, event -> showDialog("Hello World", "Hello World!"));
						item.addListener(SWT.MenuDetect, event -> contextMenu.setVisible(true));
						waitForTrayHost(display, shell, item);
						while (!shell.isDisposed()) {
							if (!display.readAndDispatch()) {
								display.sleep();
							}
						}
					} finally {
						item.dispose();
					}
				} finally {
					icon.dispose();
				}
			} finally {
				if (!display.isDisposed()) {
					display.dispose();
				}
				display = null;
			}
		}
		return EXIT_OK;
	}

	private static void waitForTrayHost(Display display, Shell shell, TrayItem item) {
		if (!"gtk".equals(SWT.getPlatform())) {
			return;
		}
		long timeout = TimeUnit.SECONDS.toNanos(5);
		long deadline = System.nanoTime() + timeout;
		display.timerExec(5_000, () -> {});
		// GTK can create a tray item even when no desktop tray host is present.
		while (!shell.isDisposed() && !GtkTraySupport.isEmbedded(item)) {
			if (System.nanoTime() - deadline >= 0) {
				throw new IllegalStateException("System tray host is unavailable.");
			}
			if (!display.readAndDispatch()) {
				display.sleep();
			}
		}
	}

	private static FileLock acquireLock(FileChannel channel) throws IOException {
		try {
			FileLock lock = channel.tryLock();
			if (lock != null) {
				return lock;
			}
		} catch (OverlappingFileLockException e) {
			throw new IllegalStateException("Tray App is already running.", e);
		}
		throw new IllegalStateException("Tray App is already running.");
	}

	private static Image createIcon(Display display) {
		Image image = new Image(display, 16, 16);
		GC gc = new GC(image);
		try {
			gc.setBackground(display.getSystemColor(SWT.COLOR_DARK_BLUE));
			gc.fillRectangle(0, 0, 16, 16);
			gc.setForeground(display.getSystemColor(SWT.COLOR_WHITE));
			gc.drawRectangle(3, 3, 9, 9);
		} finally {
			gc.dispose();
		}
		return image;
	}

	private Menu createMenu(boolean context) {
		Menu menu = new Menu(shell, SWT.POP_UP);
		addItem(menu, "Hello World...", () -> showDialog("Hello World", "Hello World!"));
		if (context) {
			addItem(menu, "Preferences...", () -> showDialog("Preferences", "Preferences are not implemented."));
			new MenuItem(menu, SWT.SEPARATOR);
		} else {
			addItem(menu, "About", () -> showDialog("About", "SWT system tray example."));
		}
		addItem(menu, "Exit", () -> shell.dispose());
		return menu;
	}

	private static void addItem(Menu menu, String text, Runnable action) {
		MenuItem item = new MenuItem(menu, SWT.PUSH);
		item.setText(text);
		item.addListener(SWT.Selection, event -> action.run());
	}

	private void showDialog(String title, String text) {
		MessageBox dialog = new MessageBox(shell, SWT.OK | SWT.ICON_INFORMATION);
		dialog.setText(title);
		dialog.setMessage(text);
		dialog.open();
	}

	@Override
	public void stop() {
		Display current = display;
		if (current != null && !current.isDisposed()) {
			current.syncExec(() -> {
				if (shell != null && !shell.isDisposed()) {
					shell.dispose();
				}
			});
		}
	}
}
