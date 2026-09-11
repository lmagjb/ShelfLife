//
//  AuthService.swift
//  ShelfLIFE
//
//  Created by Mac-LAB on 9/7/26.
//

import SwiftUI

// MARK: - Colors
/// Every color used in the app. Change one here and it changes everywhere.
enum AppColor {
    static let background = Color(red: 0.97, green: 0.96, blue: 0.94)  // cream
    static let card       = Color.white
    static let soft       = Color(red: 0.94, green: 0.92, blue: 0.88)  // light beige
    static let dark       = Color(red: 0.17, green: 0.20, blue: 0.16)  // deep olive
    static let text       = Color(red: 0.14, green: 0.16, blue: 0.12)
    static let gray       = Color(red: 0.43, green: 0.46, blue: 0.40)
    static let green      = Color(red: 0.48, green: 0.61, blue: 0.46)  // sage
    static let orange     = Color(red: 0.91, green: 0.70, blue: 0.30)  // amber
    static let red        = Color(red: 0.84, green: 0.35, blue: 0.29)  // coral
    static let brown      = Color(red: 0.85, green: 0.49, blue: 0.33)  // terracotta
    static let border     = Color(red: 0.89, green: 0.87, blue: 0.82)
}

// MARK: - Card background
/// White box with a thin border and rounded corners.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .cornerRadius(16)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - One row in a list
struct ItemRow: View {
    let item: ShelfItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(item.color.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColor.text)
                Text(item.store)
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.gray)
            }

            Spacer()

            Text(item.deadlineText)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(item.color.opacity(0.15))
                .foregroundColor(item.color)
                .cornerRadius(10)
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Buttons
struct FilledButton: View {
    let title: String
    var color: Color = AppColor.dark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .cornerRadius(24)
        }
    }
}

struct OutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppColor.border, lineWidth: 1)
                )
                .cornerRadius(24)
        }
    }
}

// MARK: - Section heading
struct Heading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(AppColor.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Small stat box
struct StatBox: View {
    let value: String
    let label: String
    var color: Color = AppColor.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColor.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Key / value line
struct DetailLine: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 14))
                .foregroundColor(AppColor.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.text)
        }
    }
}

// MARK: - Message shown when a list is empty
struct EmptyMessage: View {
    let emoji: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 50))
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppColor.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppColor.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}
