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

import java.lang.reflect.InvocationTargetException;

public class SecondInstanceProbe {
	public static void main(String[] args) throws Exception {
		Class<?> appType = Class.forName("example.rcp.tray.TrayApplication");
		Class<?> contextType = Class.forName("org.eclipse.equinox.app.IApplicationContext");
		if (args.length == 1 && "run".equals(args[0])) {
			appType.getMethod("start", contextType).invoke(appType.getConstructor().newInstance(), (Object) null);
			return;
		}
		try {
			appType.getMethod("start", contextType).invoke(appType.getConstructor().newInstance(), (Object) null);
			throw new AssertionError("Second application unexpectedly started");
		} catch (InvocationTargetException exception) {
			Throwable cause = exception.getCause();
			if (!(cause instanceof IllegalStateException) || !"Tray App is already running.".equals(cause.getMessage())) {
				throw exception;
			}
			System.out.println("Second application rejected");
		}
	}
}
