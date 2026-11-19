using System;

public class Solution
{
    public int[] ProductExceptSelf(int[] nums)
    {
        return UsingConstantExtraSpace(nums);
    }
    public int[] UsingPrefixAndSuffixArrays(int[] nums)
    {
        ArgumentNullException.ThrowIfNull(nums);

        int length = nums.Length;
        int[] result = new int[length];

        if (length == 0)
        {
            return result;
        }

        int[] prefix = new int[length];
        int[] suffix = new int[length];

        prefix[0] = 1;
        for (int i = 1; i < length; i++)
        {
            prefix[i] = prefix[i - 1] * nums[i - 1];
        }

        suffix[length - 1] = 1;
        for (int i = length - 2; i >= 0; i--)
        {
            suffix[i] = suffix[i + 1] * nums[i + 1];
        }

        for (int i = 0; i < length; i++)
        {
            result[i] = prefix[i] * suffix[i];
        }

        return result;
    }

    public int[] UsingConstantExtraSpace(int[] nums)
    {
        ArgumentNullException.ThrowIfNull(nums);

        int length = nums.Length;
        int[] result = new int[length];
        int prefixProduct = 1;

        for (int i = 0; i < length; i++)
        {
            result[i] = prefixProduct;
            prefixProduct *= nums[i];
        }

        int suffixProduct = 1;
        for (int i = length - 1; i >= 0; i--)
        {
            result[i] *= suffixProduct;
            suffixProduct *= nums[i];
        }

        return result;
    }
}
