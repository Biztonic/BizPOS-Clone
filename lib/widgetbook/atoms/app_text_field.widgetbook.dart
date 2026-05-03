import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import '../../../core/design/components/atoms/app_text_field.dart';

@widgetbook.UseCase(
  name: 'Variants',
  type: AppTextField,
)
Widget appTextFieldVariantsUseCase(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        AppTextField(
          labelText: 'Outlined Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.outlined,
        ),
        SizedBox(height: 16),
        AppTextField(
          labelText: 'Filled Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.filled,
        ),
        SizedBox(height: 16),
        AppTextField(
          labelText: 'Underlined Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.underlined,
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Sizes',
  type: AppTextField,
)
Widget appTextFieldSizesUseCase(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        AppTextField(
          labelText: 'Small Size',
          size: AppTextFieldSize.small,
        ),
        SizedBox(height: 16),
        AppTextField(
          labelText: 'Medium Size',
          size: AppTextFieldSize.medium,
        ),
        SizedBox(height: 16),
        AppTextField(
          labelText: 'Large Size',
          size: AppTextFieldSize.large,
        ),
      ],
    ),
  );
}
