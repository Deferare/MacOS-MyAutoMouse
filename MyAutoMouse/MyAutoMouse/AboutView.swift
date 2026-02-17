//
//  AboutView.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "cursorarrow.click.badge.clock")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 40)

                    VStack(spacing: 4) {
                        Text("MyAutoMouse")
                            .font(.system(.title, design: .rounded).bold())

                        Text("Version 1.0.0")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("A simple, minimalist mouse macro utility\ndesigned for efficiency on macOS.")
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 16) {
                    AboutBullet(icon: "lock.shield.fill", text: "Securely interacts with accessibility services.")
                    AboutBullet(icon: "cursorarrow.rays", text: "Supports multiple mouse buttons and positions.")
                    AboutBullet(icon: "timer", text: "Precision timing for automation tasks.")
                }
                .padding(.vertical, 8)

                Divider()
                    .frame(width: 100)

                Text("© 2026 JiHoon K.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
        }
    }
}

private struct AboutBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}
