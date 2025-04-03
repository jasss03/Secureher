package com.example.shesecure.activitypages;

import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.FragmentActivity;
import androidx.viewpager2.adapter.FragmentStateAdapter;
import androidx.viewpager2.widget.ViewPager2;
import androidx.fragment.app.Fragment;
import android.os.Bundle;
import android.widget.ImageView;

import com.example.shesecure.R;
import com.example.shesecure.fragments.WizardFragment1;
import com.example.shesecure.fragments.WizardFragment2;
import com.example.shesecure.fragments.WizardFragment3;

public class WizardActivity extends AppCompatActivity {

    private ViewPager2 viewPager;
    private ImageView dot1;
    private ImageView dot2;
    private ImageView dot3;

    private ViewPager2.OnPageChangeCallback pageChangeCallback = new ViewPager2.OnPageChangeCallback() {
        @Override
        public void onPageSelected(int position) {
            updateDots(position);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_wizard);

        viewPager = findViewById(R.id.viewPager);
        dot1 = findViewById(R.id.dot1);
        dot2 = findViewById(R.id.dot2);
        dot3 = findViewById(R.id.dot3);

        WizardPagerAdapter adapter = new WizardPagerAdapter(this);
        viewPager.setAdapter(adapter);
        viewPager.registerOnPageChangeCallback(pageChangeCallback);

    }

    private void updateDots(int position) {
        dot1.setImageResource(position == 0 ? R.drawable.ic_dot_selected : R.drawable.ic_dot_unselected);
        dot2.setImageResource(position == 1 ? R.drawable.ic_dot_selected : R.drawable.ic_dot_unselected);
        dot3.setImageResource(position == 2 ? R.drawable.ic_dot_selected : R.drawable.ic_dot_unselected);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        viewPager.unregisterOnPageChangeCallback(pageChangeCallback);
    }
}

class WizardPagerAdapter extends FragmentStateAdapter {
    public WizardPagerAdapter(FragmentActivity fragmentActivity) {
        super(fragmentActivity);
    }

    @Override
    public int getItemCount() {
        return 3;
    }

    @Override
    public Fragment createFragment(int position) {
        switch (position) {
            case 0:
                return new WizardFragment1();
            case 1:
                return new WizardFragment2();
            case 2:
                return new WizardFragment3();
            default:
                throw new IllegalArgumentException("Invalid position: " + position);
        }
    }
}

