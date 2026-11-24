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

import java.nio.charset.StandardCharsets;

import org.eclipse.swt.internal.gtk.OS;
import org.eclipse.swt.widgets.TrayItem;

final class GtkTraySupport {
	private static final byte[] EMBEDDED = "embedded\0".getBytes(StandardCharsets.US_ASCII);

	private GtkTraySupport() {}

	static boolean isEmbedded(TrayItem item) {
		int[] embedded = new int[1];
		OS.g_object_get(item.handle, EMBEDDED, embedded, 0);
		return embedded[0] != 0;
	}
}
